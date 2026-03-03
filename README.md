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
  - user progress synced via validated Edge Function
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

Project already provisioned:
- Project ref: `lwmmajjoytkqbfnxxghb`
- URL: `https://lwmmajjoytkqbfnxxghb.supabase.co`

Applied by CLI:
- project creation
- schema + RLS + leaderboard views migrations
- initial Sudoku/Queens seed rows
- score submit function: `submit-score`
- anti-cheat guardrails in function:
  - rate limit (per user / 5-minute window)
  - daily attempt cap per puzzle
  - unrealistic-time and streak-jump validation
  - hint usage tracked and applied to puzzle leaderboard score (`+20s` per hint)
  - puzzle session save function: `save-puzzle-session`
  - puzzle ingest function: `ingest-puzzles`

Still required in Supabase dashboard:
1. In Auth providers, enable Google OAuth and configure Google client ID/secret.
2. Configure mobile deep-link redirect:
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

Or use the prepared local file and script:

```bash
./scripts/run_supabase.sh
```

## Puzzle Builder Service (Daily + Manual Backlog)

Generates and uploads daily Sudoku puzzles:
- 3 puzzles per day (`Easy`, `Medium`, `Hard`)
- validates puzzles are uniquely solvable before upload
- computes SHA-256 hash and avoids duplicates

### Setup

1. Create builder env file:
```bash
cp .env.puzzle_builder.example .env.puzzle_builder
```
2. Fill real values in `.env.puzzle_builder`:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `PUZZLE_BUILDER_SECRET` (must match Supabase function secret)

### Manual run

Generate/upload today:
```bash
./scripts/run_puzzle_builder.sh --days 1
```

Generate backlog from a date:
```bash
./scripts/run_puzzle_builder.sh --start-date 2026-03-01 --days 30
```

Dry run only (no upload):
```bash
./scripts/run_puzzle_builder.sh --start-date 2026-03-01 --days 7 --dry-run
```

### Install daily systemd timer on this machine

```bash
./scripts/install_puzzle_builder_service.sh
```

Timer/unit files:
- `deploy/systemd/logic-puzzle-builder.service`
- `deploy/systemd/logic-puzzle-builder.timer`

## Next implementation steps

1. Replace placeholder Sudoku/Queens screens with full interactive game engines.
2. Expand anti-cheat validation rules (device attestation / anomaly scoring).
3. Add migration/versioning workflow for schema updates.
4. Add integration tests for auth + sync + leaderboard queries.
