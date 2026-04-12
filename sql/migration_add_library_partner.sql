-- Optional migration for existing databases (run once).
-- psql -U postgres -d echo_reading -f sql/migration_add_library_partner.sql

alter table read_logs add column if not exists library_partner_name text;
create index if not exists read_logs_library_partner_idx
  on read_logs (library_partner_name)
  where library_partner_name is not null;
