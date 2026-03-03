create table if not exists score_submission_events (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  puzzle_id text,
  type text,
  completed boolean not null default false,
  best_seconds integer not null default 0,
  streak_days integer not null default 0,
  accepted boolean not null,
  reason_code text not null,
  created_at timestamptz not null default now()
);

create index if not exists score_submission_events_user_time_idx
  on score_submission_events (user_id, created_at desc);

create index if not exists score_submission_events_user_puzzle_time_idx
  on score_submission_events (user_id, puzzle_id, created_at desc);

alter table score_submission_events enable row level security;

drop policy if exists score_events_owner_read on score_submission_events;
create policy score_events_owner_read
on score_submission_events for select
using (auth.uid() = user_id);
