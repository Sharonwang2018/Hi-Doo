-- =============================================================================
-- Hi-Doo + Supabase Auth（新库）：books + read_logs，user_id → auth.users(id)
-- 在 SQL Editor 一次执行。Auth 用户由 Supabase 管理，勿再建 public.users。
-- =============================================================================

create extension if not exists pgcrypto;

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
  user_id uuid not null references auth.users (id) on delete cascade,
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

-- 扫码录书：匿名可写 books（与 rls_policies 一致）
alter table public.books enable row level security;
drop policy if exists "Allow public read on books" on public.books;
drop policy if exists "Allow public insert on books" on public.books;
drop policy if exists "Allow public update on books" on public.books;
create policy "Allow public read on books" on public.books for select using (true);
create policy "Allow public insert on books" on public.books for insert with check (true);
create policy "Allow public update on books" on public.books for update using (true);
