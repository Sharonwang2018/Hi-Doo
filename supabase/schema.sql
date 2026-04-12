-- EchoReading core tables for Supabase
-- Run this script in Supabase SQL Editor.

create extension if not exists pgcrypto;

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
  -- e.g. retelling, quiz_challenge, storyteller_challenge, combined_challenge, log_only (quick log, no AI challenge)
  session_type text not null default 'retelling',
  library_partner_name text,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists read_logs_user_id_idx on public.read_logs (user_id);
create index if not exists read_logs_book_id_idx on public.read_logs (book_id);
create index if not exists read_logs_created_at_idx on public.read_logs (created_at desc);

-- RLS 策略：允许匿名用户对 books 表进行读写（扫码录入）；可重复执行
alter table public.books enable row level security;
drop policy if exists "Allow public read on books" on public.books;
drop policy if exists "Allow public insert on books" on public.books;
drop policy if exists "Allow public update on books" on public.books;
create policy "Allow public read on books" on public.books for select using (true);
create policy "Allow public insert on books" on public.books for insert with check (true);
create policy "Allow public update on books" on public.books for update using (true);
