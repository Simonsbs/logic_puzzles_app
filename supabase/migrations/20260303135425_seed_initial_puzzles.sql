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
