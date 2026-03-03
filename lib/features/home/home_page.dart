import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logic_puzzles_app/core/models/leaderboard_entry.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';
import 'package:logic_puzzles_app/features/coming_soon/coming_soon_page.dart';
import 'package:logic_puzzles_app/features/home/puzzle_type_card.dart';
import 'package:logic_puzzles_app/features/queens/queens_page.dart';
import 'package:logic_puzzles_app/features/sudoku/sudoku_page.dart';
import 'package:logic_puzzles_app/state/app_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider).value;
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logic Games'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                config.supabaseEnabled ? 'Supabase' : 'Local mode',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final auth = ref.read(authServiceProvider);
              if (auth.currentUser == null) {
                await auth.signInWithGoogle();
                return;
              }
              await auth.signOut();
            },
            child: Text(user == null ? 'Sign in' : 'Sign out'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            user == null ? 'Play as guest (sign in to sync progress).' : 'Hi ${user.displayName}',
          ),
          const SizedBox(height: 16),
          Text('Puzzle Types', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...PuzzleType.values.map(
            (type) => PuzzleTypeCard(
              type: type,
              onTap: () => _openPuzzleType(context, type),
            ),
          ),
          const SizedBox(height: 16),
          Text('Leaderboards', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          _LeaderboardSection(title: 'Sudoku', provider: sudokuTypeLeaderboardProvider),
          _LeaderboardSection(title: 'Queens', provider: queensTypeLeaderboardProvider),
          _LeaderboardSection(title: 'Daily streaks', provider: streakLeaderboardProvider),
        ],
      ),
    );
  }

  void _openPuzzleType(BuildContext context, PuzzleType type) {
    switch (type) {
      case PuzzleType.sudoku:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SudokuPage()),
        );
      case PuzzleType.queens:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const QueensPage()),
        );
      case PuzzleType.kakuro:
      case PuzzleType.nonogram:
      case PuzzleType.minesweeper:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ComingSoonPage(puzzleName: type.displayName),
          ),
        );
    }
  }
}

class _LeaderboardSection extends ConsumerWidget {
  const _LeaderboardSection({required this.title, required this.provider});

  final String title;
  final FutureProvider<List<LeaderboardEntry>> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(provider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            data.when(
              data: (rows) => Column(
                children: rows
                    .map(
                      (row) => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text('#${row.rank} ${row.userName}'),
                          Text('${row.score} ${row.label}'),
                        ],
                      ),
                    )
                    .toList(),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Failed to load leaderboard'),
            ),
          ],
        ),
      ),
    );
  }
}
