/**
 * Supabase（*.supabase.co）在 Node pg 下常需放宽 TLS 校验，否则易出现
 * "self-signed certificate in certificate chain"。本地 postgres 不启用 ssl。
 *
 * 注意：连接串里的 sslmode=require 会被 pg 解析成严格校验证书，往往覆盖 Pool 的
 * ssl.rejectUnauthorized。对 Supabase 应去掉查询串里的 sslmode，仅用下方 ssl 对象。
 */
function stripSslRelatedQueryParams(connectionString) {
  const q = connectionString.indexOf('?');
  if (q === -1) return connectionString;
  const base = connectionString.slice(0, q);
  const query = connectionString.slice(q + 1);
  const params = new URLSearchParams(query);
  params.delete('sslmode');
  params.delete('sslrootcert');
  const s = params.toString();
  return s ? `${base}?${s}` : base;
}

export function buildPgPoolConfig() {
  let connectionString =
    process.env.DATABASE_URL || 'postgresql://localhost:5432/echo_reading';
  const isSupabase = /supabase\.co/i.test(connectionString);
  if (isSupabase) {
    connectionString = stripSslRelatedQueryParams(connectionString);
  }
  return {
    connectionString,
    ...(isSupabase ? { ssl: { rejectUnauthorized: false } } : {}),
  };
}
