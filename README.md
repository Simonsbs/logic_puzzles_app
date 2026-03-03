# Logic Puzzles App (Flutter)

Free, no-ads, offline-first logic games app with cloud sync architecture.

## Scope in this starter

- Puzzle picker with:
  - Sudoku (active)
  - Queens (active)
  - Other puzzle types marked as coming soon
- Local puzzle storage and offline fallback
- Remote puzzle source abstraction (daily/future/past ready)
- Google sign-in service layer
- Progress sync service interface
- Leaderboards for:
  - puzzle type
  - specific puzzle
  - streaks

## Recommended backend (simple and cost-aware)

Use Supabase first for fastest launch:
- Auth: Google SSO
- Database: Postgres for puzzles/progress/leaderboards
- Edge functions or RPC for score validation and ranking updates

This keeps the app 100% free for users and minimizes ops complexity for you.

## Run

```bash
flutter pub get
flutter run
```

## Next implementation steps

1. Replace `PuzzleApiClient` with real endpoints.
2. Replace mock sync and leaderboard services with API-backed services.
3. Add full Sudoku/Queens game engines and validation.
4. Add conflict resolution rules for multi-device sync.
