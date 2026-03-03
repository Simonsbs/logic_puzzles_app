import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logic_puzzles_app/core/models/puzzle.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';
import 'package:logic_puzzles_app/core/models/user_progress.dart';
import 'package:logic_puzzles_app/core/services/progress_sync_service.dart';
import 'package:logic_puzzles_app/state/app_providers.dart';

class SudokuPage extends ConsumerStatefulWidget {
  const SudokuPage({super.key});

  @override
  ConsumerState<SudokuPage> createState() => _SudokuPageState();
}

class _SudokuPageState extends ConsumerState<SudokuPage> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sudoku')),
      body: FutureBuilder<Puzzle>(
        future: ref.read(puzzleRepositoryProvider).getPuzzle(PuzzleType.sudoku, daily: true),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final puzzle = snapshot.data!;
          final grid = (puzzle.payload['grid'] as List)
              .map((row) => List<int>.from(row as List))
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Text('${puzzle.title} - ${puzzle.difficulty}'),
              const SizedBox(height: 12),
              ...grid.map((row) => Text(row.map((v) => v == 0 ? '.' : '$v').join(' '))),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _done
                    ? null
                    : () async {
                        try {
                          await ref.read(progressSyncServiceProvider).syncProgress(
                                UserProgress(
                                  puzzleId: puzzle.id,
                                  type: PuzzleType.sudoku,
                                  completed: true,
                                  bestSeconds: 420,
                                  streakDays: 5,
                                ),
                              );
                          if (!mounted) {
                            return;
                          }
                          setState(() => _done = true);
                        } on ProgressSyncException catch (error) {
                          if (!mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.message)),
                          );
                        }
                      },
                child: Text(_done ? 'Synced' : 'Mark complete + sync'),
              ),
            ],
          );
        },
      ),
    );
  }
}
