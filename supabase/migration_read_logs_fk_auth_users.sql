-- =============================================================================
-- Supabase Auth + Hi-Doo Node API：read_logs.user_id → auth.users(id) ON DELETE CASCADE
--
-- 前置：Authentication → Providers 已启用 Email（及可选 Anonymous）。
-- 执行前请备份。若当前外键指向 profiles 或 public.users，本脚本会替换。
-- =============================================================================

-- 诊断
select
  (select count(*) from public.read_logs) as read_logs_total,
  (select count(*)
   from public.read_logs r
   where not exists (select 1 from auth.users u where u.id = r.user_id)) as rows_not_in_auth_users;

begin;

delete from public.read_logs r
where not exists (
  select 1 from auth.users u where u.id = r.user_id
);

alter table public.read_logs drop constraint if exists read_logs_user_id_fkey;

alter table public.read_logs
  add constraint read_logs_user_id_fkey
  foreign key (user_id) references auth.users (id) on delete cascade;

commit;

-- 验证：
-- select conname, pg_get_constraintdef(oid) from pg_constraint where conname = 'read_logs_user_id_fkey';

-- 可选：删除已不再使用的 Node 自建用户表（确认无其它外键引用后）
-- drop table if exists public.users cascade;
