/**
 * Vercel Edge Middleware — proxies API routes to your Node/Postgres backend.
 * Set BACKEND_ORIGIN in Vercel (e.g. https://api.yourdomain.com).
 * Set Vercel project region to Washington, D.C. (iad1) for US East.
 */
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

export default async function middleware(request) {
  const base = backendBase();
  if (!base) {
    return new Response(
      JSON.stringify({
        error: 'edge_misconfigured',
        message: 'Set BACKEND_ORIGIN in Vercel environment variables.',
      }),
      { status: 503, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const u = new URL(request.url);
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
