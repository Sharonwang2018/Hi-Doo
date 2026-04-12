import pg from 'pg';
import { buildPgPoolConfig } from './pg_config.js';

const { Pool } = pg;

const pool = new Pool(buildPgPoolConfig());

export async function query(text, params) {
  const res = await pool.query(text, params);
  return res;
}

export default pool;
