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
              _MetaCard(title: puzzle.title, difficulty: puzzle.difficulty),
              const SizedBox(height: 12),
              _SudokuBoard(grid: grid),
              const SizedBox(height: 16),
              FilledButton.icon(
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
                icon: Icon(_done ? Icons.check_circle : Icons.cloud_upload),
                label: Text(_done ? 'Synced' : 'Mark complete + sync'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.title, required this.difficulty});

  final String title;
  final String difficulty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.grid_view_rounded),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F5ED),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(difficulty),
          ),
        ],
      ),
    );
  }
}

class _SudokuBoard extends StatelessWidget {
  const _SudokuBoard({required this.grid});

  final List<List<int>> grid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        children: grid
            .map(
              (row) => Row(
                children: row
                    .map(
                      (value) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: value == 0 ? const Color(0xFFF2F5F3) : const Color(0xFFE4F2EB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              value == 0 ? '·' : '$value',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            )
            .toList(),
      ),
    );
  }
}
