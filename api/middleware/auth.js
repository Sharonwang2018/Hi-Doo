import jwt from 'jsonwebtoken';
import { createRemoteJWKSet, jwtVerify } from 'jose';

const SUPABASE_JWT_SECRET = process.env.SUPABASE_JWT_SECRET?.trim();
const SUPABASE_URL = process.env.SUPABASE_URL?.trim().replace(/\/$/, '') ?? '';

/** Lazy JWKS for asymmetric (e.g. ES256) user access tokens after JWT Signing Keys migration. */
let jwksRemote = null;
function getJwks() {
  if (!SUPABASE_URL) return null;
  if (!jwksRemote) {
    jwksRemote = createRemoteJWKSet(
      new URL(`${SUPABASE_URL}/auth/v1/.well-known/jwks.json`),
    );
  }
  return jwksRemote;
}

function isAuthConfigured() {
  return Boolean(SUPABASE_JWT_SECRET || SUPABASE_URL);
}

/**
 * Verifies Supabase Auth access token: HS256 + legacy secret, or ES256/RS256 via project JWKS.
 * New projects with "JWT Signing Keys" (ECC) issue ES256 tokens — same Legacy secret string does not verify them.
 */
async function verifySupabaseAccessToken(token) {
  const decoded = jwt.decode(token, { complete: true });
  if (!decoded?.header?.alg) {
    throw new Error('invalid token');
  }
  const { alg } = decoded.header;

  if (alg === 'HS256') {
    if (!SUPABASE_JWT_SECRET) {
      throw new Error('SUPABASE_JWT_SECRET missing for HS256');
    }
    return jwt.verify(token, SUPABASE_JWT_SECRET, { algorithms: ['HS256'] });
  }

  const jwks = getJwks();
  if (!jwks) {
    throw new Error('SUPABASE_URL missing for asymmetric JWT');
  }
  const issuer = `${SUPABASE_URL}/auth/v1`;
  // Supabase user access tokens always include aud; jose rejects if audience is omitted.
  // See https://supabase.com/docs/guides/auth/jwt-fields
  const { payload } = await jwtVerify(token, jwks, {
    issuer,
    audience: ['authenticated', 'anon'],
    clockTolerance: 30,
    algorithms: ['ES256', 'ES384', 'ES512', 'RS256', 'RS384', 'RS512', 'EdDSA'],
  });
  return payload;
}

function applyPayload(req, payload) {
  const sub = payload.sub;
  if (!sub || typeof sub !== 'string') {
    return false;
  }
  req.userId = sub;
  req.username = payload.email || payload.phone || '';
  req.isGuest = payload.is_anonymous === true;
  return true;
}

export function authMiddleware(req, res, next) {
  if (!isAuthConfigured()) {
    return res.status(503).json({
      error: 'server_misconfigured',
      message:
        'Set SUPABASE_URL (https://xxx.supabase.co) for ES256/JWKS and/or SUPABASE_JWT_SECRET for HS256 in api/.env.',
    });
  }
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'unauthorized', message: '缺少 token' });
  }
  const token = auth.slice(7);
  verifySupabaseAccessToken(token)
    .then((payload) => {
      if (!applyPayload(req, payload)) {
        return res.status(401).json({ error: 'unauthorized', message: 'token 无效' });
      }
      next();
    })
    .catch(() => {
      res.status(401).json({ error: 'unauthorized', message: 'token 无效' });
    });
}

export function optionalAuth(req, res, next) {
  if (!isAuthConfigured()) {
    req.userId = null;
    req.isGuest = false;
    req.username = '';
    return next();
  }
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith('Bearer ')) {
    req.userId = null;
    req.isGuest = false;
    req.username = '';
    return next();
  }
  const token = auth.slice(7);
  verifySupabaseAccessToken(token)
    .then((payload) => {
      if (applyPayload(req, payload)) {
        // ok
      } else {
        req.userId = null;
        req.isGuest = false;
        req.username = '';
      }
      next();
    })
    .catch(() => {
      req.userId = null;
      req.isGuest = false;
      req.username = '';
      next();
    });
}

/** Anonymous JWT cannot write logs or upload; browse-only clients have no token or must sign in. */
export function rejectGuestWrite(req, res) {
  if (req.isGuest) {
    res.status(403).json({
      error: 'guest_cannot_save',
      message: 'Sign in with email or Google to save your reading journey.',
    });
    return true;
  }
  return false;
}
