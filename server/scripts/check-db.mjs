#!/usr/bin/env node
/**
 * 与 server 一致：先加载 load-env（含 DIRECT_URL → DATABASE_URL），再测连。
 * 用法：cd api && npm run check-db
 */
import '../load-env.js';
import path from 'path';
import { fileURLToPath } from 'url';
import pg from 'pg';
import { buildPgPoolConfig } from '../pg_config.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const envPath = path.join(__dirname, '..', '.env');

/** 解析连接串中的用户名、主机、端口（不把密码打日志）。 */
function parsePgConnParts(connectionString) {
  try {
    const normalized = connectionString.replace(/^postgresql:/i, 'http:');
    const url = new URL(normalized);
    return {
      user: decodeURIComponent(url.username || ''),
      host: url.hostname,
      port: url.port || '5432',
    };
  } catch {
    return null;
  }
}

const conn = process.env.DATABASE_URL?.trim();
if (!conn) {
  console.error(
    '未设置 DATABASE_URL（若只用 DIRECT_URL，请写在 api/.env，load-env 会合并）。',
  );
  process.exit(1);
}
if (process.env.DIRECT_URL?.trim()) {
  console.log('提示: 已配置 DIRECT_URL 时，load-env 会用它作为实际连接（覆盖 DATABASE_URL）。');
}

const masked = conn.replace(/:([^:@/]*)@/, ':****@');
console.log('读取:', envPath);
console.log('连接串(已隐藏密码):', masked);
const parts = parsePgConnParts(conn);
if (parts) {
  console.log(
    `解析: 用户="${parts.user}" 主机=${parts.host}:${parts.port}`,
  );
}

const pool = new pg.Pool(buildPgPoolConfig());
try {
  await pool.query('select 1 as ok');
  console.log('结果: OK — 数据库连接正常。');
  process.exit(0);
} catch (e) {
  console.error('结果: 失败 —', e.message);
  console.error('');
  console.error('常见原因：');
  console.error('  1) 密码应是 Supabase → Database 的「Database password」，不是 anon / service_role。');
  console.error('  2) 密码含 @#:/ 等请先 URL 编码。');
  console.error('  3) Session pooler 用 :5432；6543 + pgbouncer 为 Transaction，易与 ORM/长事务不搭。');
  if (/password authentication failed/i.test(String(e.message)) && /pooler\.supabase\.com/i.test(conn)) {
    const ref = parts?.user?.startsWith('postgres.') ? parts.user.slice('postgres.'.length) : '<project-ref>';
    console.error('');
    console.error('Pooler 上密码一直失败时，可改试「Direct」连接（同一 Database password）：');
    console.error(
      `  DIRECT_URL=postgresql://postgres:编码后的密码@db.${ref}.supabase.co:5432/postgres`,
    );
    console.error('  用户名固定为 postgres（无 . 后缀），主机为 db.<ref>.supabase.co。');
  }
  if (/certificate/i.test(String(e.message))) {
    console.error('');
    console.error('若仍报证书错误：请拉取最新代码（api/pg_config.js 已为 Supabase 设置 ssl）。');
  }
  process.exit(1);
} finally {
  await pool.end();
}
