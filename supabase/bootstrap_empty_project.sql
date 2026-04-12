-- =============================================================================
-- Supabase Auth 路线：profiles + auth.users + read_logs（与 Supabase 登录配套）
--
-- 本仓库自带的 Node API（JWT、/auth/guest、public.users）请用 schema_node_api.sql，
-- 不要用本文件，否则和 API 的 users / read_logs 外键不一致。
-- =============================================================================
-- 若报错 relation "read_logs" does not exist：在 SQL Editor 中执行本文件全文。
-- =============================================================================

create extension if not exists pgcrypto;

-- ----- 核心表 -----
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nickname text not null,
  age int2 not null check (age between 3 and 8),
  avatar_url text
);

create table if not exists public.books (
  id uuid primary key default gen_random_uuid(),
  isbn text not null unique,
  title text not null,
  author text not null,
  cover_url text,
  summary text
);

create table if not exists public.read_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  book_id uuid not null references public.books (id) on delete cascade,
  audio_url text,
  transcript text,
  ai_feedback text,
  language text,
  session_type text not null default 'retelling',
  library_partner_name text,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists read_logs_user_id_idx on public.read_logs (user_id);
create index if not exists read_logs_book_id_idx on public.read_logs (book_id);
create index if not exists read_logs_created_at_idx on public.read_logs (created_at desc);
create index if not exists read_logs_library_partner_idx
  on public.read_logs (library_partner_name)
  where library_partner_name is not null;

-- ----- books：匿名扫码写入 -----
alter table public.books enable row level security;

drop policy if exists "Allow public read on books" on public.books;
drop policy if exists "Allow public insert on books" on public.books;
drop policy if exists "Allow public update on books" on public.books;

create policy "Allow public read on books" on public.books
  for select using (true);

create policy "Allow public insert on books" on public.books
  for insert with check (true);

create policy "Allow public update on books" on public.books
  for update using (true);

-- ----- 与 migration_language_and_shared.sql 一致：新用户 profile、read_logs RLS -----
alter table public.read_logs
  add column if not exists language text,
  add column if not exists session_type text not null default 'retelling';

alter table public.read_logs alter column audio_url drop not null;

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

alter table public.profiles enable row level security;
drop policy if exists "Users can read own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can read own profile" on public.profiles for select using (auth.uid() = id);
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);
create policy "Users can insert own profile" on public.profiles for insert with check (auth.uid() = id);

alter table public.read_logs enable row level security;
drop policy if exists "Users can read own read_logs" on public.read_logs;
drop policy if exists "Users can insert own read_logs" on public.read_logs;
create policy "Users can read own read_logs" on public.read_logs for select using (auth.uid() = user_id);
create policy "Users can insert own read_logs" on public.read_logs for insert with check (auth.uid() = user_id);

insert into public.profiles (id, nickname, age)
select u.id, '小读者', 5 from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id)
on conflict (id) do nothing;
