alter table user_progress
  add column if not exists hints_used integer not null default 0;

alter table score_submission_events
  add column if not exists hints_used integer not null default 0;

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
