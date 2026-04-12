// 必须在其它业务 import 之前执行，确保 process.env 已加载
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '.env') });

// Supabase：若同时写了 DATABASE_URL（常为 6543 Transaction）和 DIRECT_URL（常为 5432 Session），优先用 DIRECT_URL。
const direct = process.env.DIRECT_URL?.trim();
if (direct) {
  process.env.DATABASE_URL = direct;
}
