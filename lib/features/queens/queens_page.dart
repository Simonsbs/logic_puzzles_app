import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logic_puzzles_app/core/models/puzzle.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';
import 'package:logic_puzzles_app/core/models/user_progress.dart';
import 'package:logic_puzzles_app/core/services/progress_sync_service.dart';
import 'package:logic_puzzles_app/state/app_providers.dart';

class QueensPage extends ConsumerStatefulWidget {
  const QueensPage({super.key});

  @override
  ConsumerState<QueensPage> createState() => _QueensPageState();
}

class _QueensPageState extends ConsumerState<QueensPage> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Queens')),
      body: FutureBuilder<Puzzle>(
        future: ref.read(puzzleRepositoryProvider).getPuzzle(PuzzleType.queens, daily: true),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final puzzle = snapshot.data!;
          final size = puzzle.payload['size'] as int;
          final blocked = (puzzle.payload['blocked'] as List)
              .map((e) => List<int>.from(e as List))
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Text('${puzzle.title} - ${puzzle.difficulty}'),
              const SizedBox(height: 12),
              Text('Board: $size x $size'),
              Text('Blocked cells: ${blocked.map((c) => '(${c[0]},${c[1]})').join(', ')}'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _done
                    ? null
                    : () async {
                        try {
                          await ref.read(progressSyncServiceProvider).syncProgress(
                                UserProgress(
                                  puzzleId: puzzle.id,
                                  type: PuzzleType.queens,
                                  completed: true,
                                  bestSeconds: 295,
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
