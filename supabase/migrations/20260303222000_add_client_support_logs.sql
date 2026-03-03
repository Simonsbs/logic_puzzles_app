create table if not exists client_logs (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  log_type text not null default 'support',
  message text not null,
  payload jsonb,
  created_at timestamptz not null default now()
);

create index if not exists client_logs_user_created_idx
  on client_logs (user_id, created_at desc);

alter table client_logs enable row level security;

drop policy if exists client_logs_owner_read on client_logs;
create policy client_logs_owner_read
on client_logs for select
using (auth.uid() = user_id);
