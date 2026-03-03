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
              _MetaCard(title: puzzle.title, difficulty: puzzle.difficulty, size: size),
              const SizedBox(height: 12),
              _QueensBoard(size: size, blocked: blocked),
              const SizedBox(height: 12),
              Text(
                'Blocked cells: ${blocked.map((c) => '(${c[0]}, ${c[1]})').join(', ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _done
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
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
                          messenger.showSnackBar(
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
  const _MetaCard({required this.title, required this.difficulty, required this.size});

  final String title;
  final String difficulty;
  final int size;

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
          const Icon(Icons.emoji_events_outlined),
          const SizedBox(width: 10),
          Expanded(child: Text('$title ($size x $size)', style: Theme.of(context).textTheme.titleMedium)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3DF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(difficulty),
          ),
        ],
      ),
    );
  }
}

class _QueensBoard extends StatelessWidget {
  const _QueensBoard({required this.size, required this.blocked});

  final int size;
  final List<List<int>> blocked;

  @override
  Widget build(BuildContext context) {
    final blockedSet = blocked.map((cell) => '${cell[0]}-${cell[1]}').toSet();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        children: List<Widget>.generate(size, (r) {
          return Row(
            children: List<Widget>.generate(size, (c) {
              final key = '$r-$c';
              final isBlocked = blockedSet.contains(key);
              final isDark = (r + c).isEven;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.all(1),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isBlocked
                        ? const Color(0xFF3E3E3E)
                        : (isDark ? const Color(0xFFEEF2F4) : const Color(0xFFDDE6EA)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: isBlocked
                        ? const Icon(Icons.block, size: 14, color: Colors.white)
                        : const SizedBox.shrink(),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}
