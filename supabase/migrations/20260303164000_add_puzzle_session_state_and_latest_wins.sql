alter table user_progress
  add column if not exists session_elapsed_seconds integer not null default 0,
  add column if not exists session_state jsonb,
  add column if not exists session_updated_at timestamptz;

create index if not exists user_progress_user_type_updated_idx
  on user_progress (user_id, type, updated_at desc);
