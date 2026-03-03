create table if not exists puzzles (
  id text primary key,
  type text not null,
  title text not null,
  difficulty text not null,
  payload jsonb not null,
  puzzle_hash text,
  is_daily boolean not null default false,
  published_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists puzzles_type_daily_published_idx
  on puzzles (type, is_daily, published_at desc);

create unique index if not exists puzzles_type_hash_unique_idx
  on puzzles (type, puzzle_hash)
  where puzzle_hash is not null;

create table if not exists user_progress (
  user_id uuid not null,
  puzzle_id text not null,
  type text not null,
  completed boolean not null default false,
  best_seconds integer not null default 0,
  hints_used integer not null default 0,
  streak_days integer not null default 0,
  session_elapsed_seconds integer not null default 0,
  session_state jsonb,
  session_updated_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, puzzle_id)
);

alter table user_progress
  add constraint user_progress_user_fk
  foreign key (user_id) references auth.users(id) on delete cascade;

alter table user_progress
  add constraint user_progress_puzzle_fk
  foreign key (puzzle_id) references puzzles(id) on delete cascade;

create table if not exists score_submission_events (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  puzzle_id text,
  type text,
  completed boolean not null default false,
  best_seconds integer not null default 0,
  hints_used integer not null default 0,
  streak_days integer not null default 0,
  accepted boolean not null,
  reason_code text not null,
  created_at timestamptz not null default now()
);

create index if not exists score_submission_events_user_time_idx
  on score_submission_events (user_id, created_at desc);

create index if not exists score_submission_events_user_puzzle_time_idx
  on score_submission_events (user_id, puzzle_id, created_at desc);

create index if not exists user_progress_user_type_updated_idx
  on user_progress (user_id, type, updated_at desc);

insert into puzzles (id, type, title, difficulty, payload, is_daily, published_at)
values
  (
    'sudoku-starter',
    'sudoku',
    'Sudoku Starter',
    'Easy',
    '{"grid":[[0,0,0,2,6,0,7,0,1],[6,8,0,0,7,0,0,9,0],[1,9,0,0,0,4,5,0,0],[8,2,0,1,0,0,0,4,0],[0,0,4,6,0,2,9,0,0],[0,5,0,0,0,3,0,2,8],[0,0,9,3,0,0,0,7,4],[0,4,0,0,5,0,0,3,6],[7,0,3,0,1,8,0,0,0]]}'::jsonb,
    true,
    now()
  ),
  (
    'queens-starter',
    'queens',
    'Queens Starter',
    'Medium',
    '{"size":8,"blocked":[[0,6],[1,1],[3,4],[5,2]]}'::jsonb,
    true,
    now()
  )
on conflict (id) do nothing;

create or replace view leaderboard_type as
select
  row_number() over (partition by type order by count(*) desc, min(best_seconds) asc) as rank,
  type,
  coalesce(max(u.raw_user_meta_data->>'full_name'), 'Player') as user_name,
  count(*)::int as score,
  'completed'::text as label
from user_progress up
join auth.users u on u.id = up.user_id
where up.completed = true
group by type, user_id;

create or replace view leaderboard_puzzle as
select
  row_number() over (partition by puzzle_id order by min(best_seconds + (hints_used * 20)) asc) as rank,
  puzzle_id,
  coalesce(max(u.raw_user_meta_data->>'full_name'), 'Player') as user_name,
  min(best_seconds + (hints_used * 20))::int as score,
  'adjusted seconds'::text as label
from user_progress up
join auth.users u on u.id = up.user_id
where up.completed = true
group by puzzle_id, user_id;

create or replace view leaderboard_streak as
select
  row_number() over (order by max(streak_days) desc) as rank,
  coalesce(max(u.raw_user_meta_data->>'full_name'), 'Player') as user_name,
  max(streak_days)::int as score,
  'day streak'::text as label
from user_progress up
join auth.users u on u.id = up.user_id
group by user_id;

alter table puzzles enable row level security;
alter table user_progress enable row level security;
alter table score_submission_events enable row level security;

drop policy if exists puzzles_read_all on puzzles;
create policy puzzles_read_all
on puzzles for select
using (true);

drop policy if exists progress_owner_read on user_progress;
create policy progress_owner_read
on user_progress for select
using (auth.uid() = user_id);

drop policy if exists score_events_owner_read on score_submission_events;
create policy score_events_owner_read
on score_submission_events for select
using (auth.uid() = user_id);
