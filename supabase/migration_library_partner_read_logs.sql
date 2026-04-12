-- Run once in Supabase SQL Editor if read_logs predates library_partner_name.
-- Fixes: column "library_partner_name" of relation "read_logs" does not exist

alter table public.read_logs
  add column if not exists library_partner_name text;

create index if not exists read_logs_library_partner_idx
  on public.read_logs (library_partner_name)
  where library_partner_name is not null;
