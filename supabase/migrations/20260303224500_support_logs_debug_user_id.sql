alter table client_logs
  alter column user_id drop not null;

alter table client_logs
  add column if not exists debug_user_id text;

create index if not exists client_logs_debug_user_created_idx
  on client_logs (debug_user_id, created_at desc);
