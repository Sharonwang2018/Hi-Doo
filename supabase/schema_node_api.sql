-- =============================================================================
-- 【旧版】Node 自建 /auth + public.users — 当前主线已改为 Supabase Auth + auth.users。
--
-- 新部署请：1) 用 Dashboard 管理用户；2) 建 books/read_logs（read_logs.user_id → auth.users）；
--    3) 执行 migration_read_logs_fk_auth_users.sql（若表已从本文件建过，先改外键再弃用 users）。
-- 下列 DDL 仅作参考或从旧库迁移时的片段保留。
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

create table if not exists public.books (
  id uuid primary key default gen_random_uuid(),
  isbn text not null unique,
  title text not null,
  author text not null,
  cover_url text,
  summary text
);

create index if not exists books_isbn_idx on public.books (isbn);

create table if not exists public.read_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
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
