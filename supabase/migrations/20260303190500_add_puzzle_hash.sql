alter table puzzles
  add column if not exists puzzle_hash text;

create unique index if not exists puzzles_type_hash_unique_idx
  on puzzles (type, puzzle_hash)
  where puzzle_hash is not null;
