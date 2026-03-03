import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logic_puzzles_app/core/models/puzzle.dart';
import 'package:logic_puzzles_app/core/models/puzzle_progress_status.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';
import 'package:logic_puzzles_app/features/queens/queens_page.dart';
import 'package:logic_puzzles_app/features/sudoku/sudoku_page.dart';
import 'package:logic_puzzles_app/state/app_providers.dart';

class PuzzleListPage extends ConsumerWidget {
  const PuzzleListPage({super.key, required this.type});

  final PuzzleType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('${type.displayName} Puzzles')),
      body: FutureBuilder<(List<Puzzle>, Map<String, PuzzleProgressStatus>)>(
        future: _load(ref),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final puzzles = snapshot.data!.$1;
          final progress = snapshot.data!.$2;
          if (puzzles.isEmpty) {
            return const Center(child: Text('No puzzles available yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: puzzles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final puzzle = puzzles[index];
              final status = progress[puzzle.id];
              return _PuzzleTile(
                puzzle: puzzle,
                status: status,
                onTap: () => _openPuzzle(context, puzzle),
              );
            },
          );
        },
      ),
    );
  }

  Future<(List<Puzzle>, Map<String, PuzzleProgressStatus>)> _load(WidgetRef ref) async {
    final puzzles = await ref.read(puzzleRepositoryProvider).getPuzzles(type);
    final progress = await ref.read(puzzleProgressServiceProvider).progressByType(type);
    return (puzzles, progress);
  }

  void _openPuzzle(BuildContext context, Puzzle puzzle) {
    switch (puzzle.type) {
      case PuzzleType.sudoku:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => SudokuPage(puzzle: puzzle)));
      case PuzzleType.queens:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => QueensPage(puzzle: puzzle)));
      case PuzzleType.kakuro:
      case PuzzleType.nonogram:
      case PuzzleType.minesweeper:
        break;
    }
  }
}

class _PuzzleTile extends StatelessWidget {
  const _PuzzleTile({required this.puzzle, required this.status, required this.onTap});

  final Puzzle puzzle;
  final PuzzleProgressStatus? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completed = status?.completed ?? false;
    final dateLabel = puzzle.publishedAt == null
        ? 'Unknown date'
        : '${puzzle.publishedAt!.year}-${puzzle.publishedAt!.month.toString().padLeft(2, '0')}-${puzzle.publishedAt!.day.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x14000000)),
        ),
        child: Row(
          children: <Widget>[
            Icon(completed ? Icons.check_circle : Icons.radio_button_unchecked, color: completed ? const Color(0xFF198754) : const Color(0xFF8A9A92)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(puzzle.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('$dateLabel • ${puzzle.difficulty}'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (completed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6EE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('Done', style: TextStyle(color: Color(0xFF198754), fontWeight: FontWeight.w700)),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
