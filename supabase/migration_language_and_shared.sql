-- EchoReading 迁移：language、共读模式、新用户 profile 触发器、RLS
-- 在 Supabase SQL Editor 中执行；可重复执行（策略先 DROP 再 CREATE）。
--
-- 适用：早期已有 read_logs / profiles 的库；若你是全新库且走 Supabase Auth + read_logs→auth.users，
-- 更推荐 bootstrap_supabase_auth.sql，再按需单独执行本文件中与表结构相关的 ALTER。
-- 若 read_logs 无外键到 profiles，可跳过与 profiles 相关的段落或只执行 1–2、5–6 中与你表结构一致的部分。

-- 1. read_logs 表新增字段
alter table public.read_logs
  add column if not exists language text,
  add column if not exists session_type text not null default 'retelling';

-- 2. audio_url 改为可空（共读模式无录音）
alter table public.read_logs alter column audio_url drop not null;

-- 3. 新用户自动创建 profile（支持匿名登录）
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, nickname, age)
  values (new.id, '小读者', 5)
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 4. profiles 表 RLS：允许用户读写自己的 profile
alter table public.profiles enable row level security;
drop policy if exists "Users can read own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can read own profile" on public.profiles for select using (auth.uid() = id);
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);
create policy "Users can insert own profile" on public.profiles for insert with check (auth.uid() = id);

-- 5. read_logs 表 RLS：允许用户读写自己的记录
alter table public.read_logs enable row level security;
drop policy if exists "Users can read own read_logs" on public.read_logs;
drop policy if exists "Users can insert own read_logs" on public.read_logs;
create policy "Users can read own read_logs" on public.read_logs for select using (auth.uid() = user_id);
create policy "Users can insert own read_logs" on public.read_logs for insert with check (auth.uid() = user_id);

-- 6. 为已有 auth 用户补全 profile（若不存在）
insert into public.profiles (id, nickname, age)
select u.id, '小读者', 5 from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id)
on conflict (id) do nothing;
