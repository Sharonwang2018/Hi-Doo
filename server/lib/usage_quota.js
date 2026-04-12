import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA_FILE = path.join(__dirname, '..', 'data', 'quota_state.json');

/** 未配置 env 时的默认每日上限（注册用户 / 访客与匿名共用设备标识时） */
const DEFAULTS = {
  transcribe: { reg: 45, anon: 12 },
  tts: { reg: 150, anon: 45 },
  chat: { reg: 60, anon: 14 },
  assessment: { reg: 60, anon: 14 },
};

/** 内存 + 落盘；按 UTC 日期分桶 */
const state = {};
let persistTimer = null;

function utcDateString() {
  return new Date().toISOString().slice(0, 10);
}

function pruneOldDays() {
  const dates = Object.keys(state).sort();
  while (dates.length > 8) {
    delete state[dates.shift()];
  }
}

function getTodayMap() {
  const d = utcDateString();
  if (!state[d]) state[d] = {};
  pruneOldDays();
  return state[d];
}

function loadState() {
  try {
    if (!fs.existsSync(DATA_FILE)) return;
    const raw = fs.readFileSync(DATA_FILE, 'utf8');
    const j = JSON.parse(raw);
    if (j && typeof j === 'object') Object.assign(state, j);
  } catch (e) {
    console.warn('[quota] loadState:', e?.message || e);
  }
}

function schedulePersist() {
  clearTimeout(persistTimer);
  persistTimer = setTimeout(() => {
    try {
      fs.mkdirSync(path.dirname(DATA_FILE), { recursive: true });
      fs.writeFileSync(DATA_FILE, JSON.stringify(state), 'utf8');
    } catch (e) {
      console.warn('[quota] persist:', e?.message || e);
    }
  }, 800);
}

loadState();

export function clientIp(req) {
  const xff = req.headers['x-forwarded-for'];
  if (xff) return String(xff).split(',')[0].trim().slice(0, 80);
  return String(req.socket?.remoteAddress || 'unknown').slice(0, 80);
}

function sanitizeClientId(req) {
  const raw = req.headers['x-client-id'];
  if (!raw || typeof raw !== 'string') return '';
  const s = raw.trim().slice(0, 128);
  if (!/^[a-zA-Z0-9_-]+$/.test(s)) return '';
  return s;
}

/**
 * 注册用户：每账号独立额度。
 * 访客 JWT / 无 token：按 X-Client-Id 或 IP 共享匿名额度（避免无限注册 guest 刷接口）。
 */
export function quotaBucketKey(req) {
  const registered = req.userId && req.isGuest !== true;
  if (registered) return `r:${req.userId}`;
  const cid = sanitizeClientId(req);
  const ip = clientIp(req);
  if (cid) return `a:c:${cid}`;
  return `a:i:${ip}`;
}

function envLimit(kind, registered) {
  const u = kind.toUpperCase();
  const key = registered ? `QUOTA_${u}_REGISTERED_PER_DAY` : `QUOTA_${u}_ANON_PER_DAY`;
  const def = DEFAULTS[kind]?.[registered ? 'reg' : 'anon'];
  const v = process.env[key];
  if (v === undefined || v === '') return def;
  const n = Number(v);
  return Number.isFinite(n) && n >= 0 ? Math.floor(n) : def;
}

/** Off unless explicitly enabled (1/true/on/yes). App monetization is optional donate UI only. */
export function quotaEnabled() {
  const v = process.env.QUOTA_ENABLED?.trim().toLowerCase();
  return v === '1' || v === 'true' || v === 'on' || v === 'yes';
}

function row(kind, key) {
  const day = getTodayMap();
  const r = day[key];
  if (!r) return 0;
  return r[kind] || 0;
}

export function checkQuota(req, kind) {
  if (!quotaEnabled()) return { ok: true };

  const registered = req.userId && req.isGuest !== true;
  const limit = envLimit(kind, registered);
  if (limit <= 0) {
    return {
      ok: false,
      limit: 0,
      used: 0,
      message: 'Daily quota is disabled for this API category.',
    };
  }

  const key = quotaBucketKey(req);
  const used = row(kind, key);
  if (used >= limit) {
    return {
      ok: false,
      limit,
      used,
      message:
        'Daily free limit reached. Try again tomorrow, or sign in for a higher allowance. You can also support our mission from the home screen.',
    };
  }
  return { ok: true, limit, used, key };
}

function shouldConsume(kind, statusCode) {
  if (statusCode === 429) return false;
  if (kind === 'assessment') return statusCode === 200 || statusCode === 422;
  return statusCode === 200;
}

export function consumeQuota(req, kind, statusCode) {
  if (!quotaEnabled()) return;
  if (!shouldConsume(kind, statusCode)) return;

  const key = quotaBucketKey(req);
  const day = getTodayMap();
  if (!day[key]) day[key] = {};
  day[key][kind] = (day[key][kind] || 0) + 1;
  schedulePersist();
}
