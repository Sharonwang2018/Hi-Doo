-- Hi-Doo 绘读 - PostgreSQL schema
-- Run: psql -U postgres -d echo_reading -f sql/schema.sql
-- Or: createdb echo_reading && psql -U postgres -d echo_reading -f sql/schema.sql

create extension if not exists pgcrypto;

-- Users: username/password auth + guest (continue browsing)
create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  username text not null unique,
  password_hash text,
  nick_name text,
  avatar_url text,
  is_guest boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists users_username_idx on users (username);
create index if not exists users_is_guest_idx on users (is_guest) where is_guest = true;

-- Books: ISBN lookup, shared across users
create table if not exists books (
  id uuid primary key default gen_random_uuid(),
  isbn text not null unique,
  title text not null,
  author text not null,
  cover_url text,
  summary text
);

create index if not exists books_isbn_idx on books (isbn);

-- Read logs: user's reading records
create table if not exists read_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
  book_id uuid not null references books (id) on delete cascade,
  audio_url text,
  transcript text,
  ai_feedback text,
  language text,
  session_type text not null default 'retelling',
  library_partner_name text,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists read_logs_user_id_idx on read_logs (user_id);
create index if not exists read_logs_book_id_idx on read_logs (book_id);
create index if not exists read_logs_created_at_idx on read_logs (created_at desc);
create index if not exists read_logs_library_partner_idx on read_logs (library_partner_name) where library_partner_name is not null;
