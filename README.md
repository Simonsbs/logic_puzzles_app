# Logic Puzzles App (Flutter)

Free, no-ads, offline-first logic games app with Supabase backend support.

## Current scope

- Puzzle picker:
  - Sudoku (active)
  - Queens (active)
  - Other puzzle types marked as coming soon
- Offline-first puzzle loading:
  - fetch from Supabase when available
  - fallback to local cached/static puzzles
- Login:
  - Google SSO via Supabase Auth OAuth
- Sync:
  - user progress synced to cloud
- Leaderboards:
  - per puzzle type
  - per individual puzzle
  - daily streaks

## Architecture

- App runs in two modes:
  - `Local mode` when Supabase env vars are missing
  - `Supabase mode` when env vars are provided
- Switching mode requires no code changes.

## Supabase setup

1. Create a Supabase project.
2. In SQL editor, run [`supabase/schema.sql`](supabase/schema.sql).
3. In Auth providers, enable Google OAuth and configure redirect URL.
4. Configure mobile deep-link redirect:
   - default used by app: `com.simonsbs.logicpuzzles://login-callback/`

## Run locally (fallback mode)

```bash
flutter pub get
flutter run
```

## Run with Supabase

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=SUPABASE_AUTH_REDIRECT_URL=com.simonsbs.logicpuzzles://login-callback/
```

## Next implementation steps

1. Replace placeholder Sudoku/Queens screens with full interactive game engines.
2. Add server-side validation function for score submissions.
3. Add migration/versioning workflow for schema updates.
4. Add integration tests for auth + sync + leaderboard queries.
