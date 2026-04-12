-- =============================================================================
-- 迁移：read_logs.user_id 从 profiles(id) 改为 public.users(id) + ON DELETE CASCADE
--
-- Hi-Doo Node API（/auth/*、JWT）写入的是 public.users，不是 auth.users / profiles。
-- 若改为引用 auth.users，须改用 Supabase Auth 登录并改 API，本脚本不适用。
--
-- 用法：Supabase SQL Editor 中一次执行全文。建议先备份。
-- 前置：若尚无 public.users，下面会 CREATE TABLE IF NOT EXISTS。
-- =============================================================================

create extension if not exists pgcrypto;

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  username text not null unique,
  password_hash text,
  nick_name text,
  avatar_url text,
  is_guest boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists users_username_idx on public.users (username);
create index if not exists users_is_guest_idx on public.users (is_guest) where is_guest = true;

-- ----- 诊断：下一行会在迁移前打印总数与将被删除的行数（请确认后再继续执行后面事务）-----
select
  (select count(*) from public.read_logs) as read_logs_total,
  (select count(*)
   from public.read_logs r
   where not exists (select 1 from public.users u where u.id = r.user_id)) as read_logs_rows_to_delete;

begin;

-- 清理：无法对应到 public.users 的行（含旧 profile id、已删用户等）
delete from public.read_logs r
where not exists (
  select 1 from public.users u where u.id = r.user_id
);

alter table public.read_logs drop constraint if exists read_logs_user_id_fkey;

alter table public.read_logs
  add constraint read_logs_user_id_fkey
  foreign key (user_id) references public.users (id) on delete cascade;

commit;

-- 验证：
-- select conname, pg_get_constraintdef(oid)
-- from pg_constraint
-- where conname = 'read_logs_user_id_fkey';
