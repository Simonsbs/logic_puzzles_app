create table if not exists puzzles (
  id text primary key,
  type text not null,
  title text not null,
  difficulty text not null,
  payload jsonb not null,
  is_daily boolean not null default false,
  published_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists puzzles_type_daily_published_idx
  on puzzles (type, is_daily, published_at desc);

create table if not exists user_progress (
  user_id uuid not null,
  puzzle_id text not null,
  type text not null,
  completed boolean not null default false,
  best_seconds integer not null default 0,
  streak_days integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, puzzle_id)
);

alter table user_progress
  add constraint user_progress_user_fk
  foreign key (user_id) references auth.users(id) on delete cascade;

alter table user_progress
  add constraint user_progress_puzzle_fk
  foreign key (puzzle_id) references puzzles(id) on delete cascade;

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
  row_number() over (partition by puzzle_id order by min(best_seconds) asc) as rank,
  puzzle_id,
  coalesce(max(u.raw_user_meta_data->>'full_name'), 'Player') as user_name,
  min(best_seconds)::int as score,
  'seconds'::text as label
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

create policy if not exists puzzles_read_all
on puzzles for select
using (true);

create policy if not exists progress_owner_read
on user_progress for select
using (auth.uid() = user_id);

create policy if not exists progress_owner_write
on user_progress for insert
with check (auth.uid() = user_id);

create policy if not exists progress_owner_update
on user_progress for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
