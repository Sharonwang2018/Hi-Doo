/**
 * Vercel Edge Middleware — optionally proxies API routes to an external backend.
 *
 * - **Same-origin deploy** (Flutter web + `api/` as Vercel functions via `vercel.json`
 *   rewrites): leave `BACKEND_ORIGIN` unset, or set it to this site’s origin — we call
 *   `next()` so requests hit your serverless API instead of proxying to yourself (loop).
 * - **Split API host**: set `BACKEND_ORIGIN=https://api.example.com` (different host).
 */
import { next } from '@vercel/edge';

export const config = {
  matcher: [
    '/books',
    '/books/:path*',
    '/read-logs',
    '/read-logs/:path*',
    '/upload',
    '/upload/:path*',
    '/audio/:path*',
    '/health',
    '/api/:path*',
  ],
};

function backendBase() {
  const raw = process.env.BACKEND_ORIGIN?.trim();
  if (!raw) return null;
  return raw.replace(/\/$/, '');
}

function sameOriginHost(backendBaseUrl, requestUrl) {
  try {
    return new URL(backendBaseUrl).host === new URL(requestUrl).host;
  } catch {
    return false;
  }
}

export default async function middleware(request) {
  const base = backendBase();
  const u = new URL(request.url);

  if (!base || sameOriginHost(base, request.url)) {
    return next();
  }

  const target = `${base}${u.pathname}${u.search}`;

  const headers = new Headers(request.headers);
  headers.delete('host');

  /** @type {RequestInit & { duplex?: string }} */
  const init = {
    method: request.method,
    headers,
    redirect: 'manual',
  };

  if (request.method !== 'GET' && request.method !== 'HEAD') {
    init.body = request.body;
    init.duplex = 'half';
  }

  return fetch(target, init);
}
