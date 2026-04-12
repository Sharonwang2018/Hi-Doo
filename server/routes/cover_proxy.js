/**
 * Fetches remote book cover bytes server-side so Flutter Web can use [Image.memory]
 * for poster export (avoids CORS + canvas taint from [Image.network] + toImage).
 */
import { Router } from 'express';

const router = Router();

const FETCH_MS = Math.max(5000, Number(process.env.COVER_PROXY_FETCH_TIMEOUT_MS || 16000));
const MAX_BYTES = 6 * 1024 * 1024;

/** Hostname suffix allowlist — tighten if abuse appears. */
const ALLOW_SUFFIX = [
  'openlibrary.org',
  'archive.org',
  'books.google.com',
  'googleusercontent.com',
  'googleapis.com',
  'gstatic.com',
  'ssl-images-amazon.com',
  'media-amazon.com',
  'images-amazon.com',
  'mzstatic.com',
];

function allowedHost(host) {
  const h = String(host || '').toLowerCase();
  if (!h || h === 'localhost' || h.endsWith('.local')) return false;
  return ALLOW_SUFFIX.some((s) => h === s || h.endsWith(`.${s}`));
}

function looksLikeImage(buf) {
  if (!buf || buf.length < 12) return false;
  if (buf[0] === 0xff && buf[1] === 0xd8) return true;
  const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  if (buf.slice(0, 8).equals(png)) return true;
  if (buf.slice(0, 4).equals(Buffer.from('RIFF')) && buf.slice(8, 12).equals(Buffer.from('WEBP'))) return true;
  const g87 = Buffer.from('GIF87a');
  const g89 = Buffer.from('GIF89a');
  if (buf.slice(0, 6).equals(g87) || buf.slice(0, 6).equals(g89)) return true;
  return false;
}

router.get('/', async (req, res, next) => {
  try {
    const raw = String(req.query.url || '').trim();
    if (!raw) {
      return res.status(400).json({ error: 'missing_url' });
    }
    let target;
    try {
      target = new URL(raw);
    } catch {
      return res.status(400).json({ error: 'invalid_url' });
    }
    if (target.protocol !== 'https:') {
      return res.status(400).json({ error: 'https_only' });
    }
    if (!allowedHost(target.hostname)) {
      return res.status(403).json({ error: 'host_not_allowed' });
    }

    const ac = new AbortController();
    const timer = setTimeout(() => ac.abort(), FETCH_MS);
    let r;
    try {
      r = await fetch(target, {
        signal: ac.signal,
        redirect: 'follow',
        headers: {
          Accept: 'image/*,*/*;q=0.8',
          'User-Agent': 'Hi-Doo-CoverProxy/1.0',
        },
      });
    } finally {
      clearTimeout(timer);
    }

    if (!r.ok) {
      return res.status(502).type('text/plain').send(`upstream ${r.status}`);
    }

    const buf = Buffer.from(await r.arrayBuffer());
    if (buf.length > MAX_BYTES) {
      return res.status(413).json({ error: 'too_large' });
    }
    if (!looksLikeImage(buf)) {
      return res.status(502).type('text/plain').send('not_an_image');
    }

    let ct = (r.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
    if (!ct.startsWith('image/')) {
      ct = 'image/jpeg';
    }
    res.setHeader('Content-Type', ct);
    res.setHeader('Cache-Control', 'public, max-age=86400');
    res.send(buf);
  } catch (e) {
    if (e?.name === 'AbortError') {
      return res.status(504).type('text/plain').send('timeout');
    }
    next(e);
  }
});

export default router;
