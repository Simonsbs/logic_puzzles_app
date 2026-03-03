import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logic_puzzles_app/core/models/puzzle.dart';
import 'package:logic_puzzles_app/core/models/puzzle_progress_status.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';
import 'package:logic_puzzles_app/features/queens/queens_page.dart';
import 'package:logic_puzzles_app/features/sudoku/sudoku_page.dart';
import 'package:logic_puzzles_app/state/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PuzzleListPage extends ConsumerStatefulWidget {
  const PuzzleListPage({super.key, required this.type});

  final PuzzleType type;

  @override
  ConsumerState<PuzzleListPage> createState() => _PuzzleListPageState();
}

class _PuzzleListPageState extends ConsumerState<PuzzleListPage> {
  late Future<(List<Puzzle>, Map<String, PuzzleProgressStatus>)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.type.displayName} Puzzles')),
      body: FutureBuilder<(List<Puzzle>, Map<String, PuzzleProgressStatus>)>(
        future: _future,
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
                onTap: () => _openPuzzle(puzzles, index, status),
              );
            },
          );
        },
      ),
    );
  }

  Future<(List<Puzzle>, Map<String, PuzzleProgressStatus>)> _load() async {
    final puzzles = await ref.read(puzzleRepositoryProvider).getPuzzles(widget.type);
    final remote = await ref.read(puzzleProgressServiceProvider).progressByType(widget.type);
    final merged = Map<String, PuzzleProgressStatus>.from(remote);

    final auth = ref.read(authServiceProvider);
    final userId = auth.currentUser?.id ?? 'guest-local';
    final prefs = await SharedPreferences.getInstance();

    for (final puzzle in puzzles) {
      final localCompleted = prefs.getBool('puzzle_completed_${userId}_${puzzle.id}') ?? false;
      final remoteStatus = merged[puzzle.id];

      var localInProgress = false;
      if (puzzle.type == PuzzleType.sudoku) {
        final session = await ref.read(puzzleSessionServiceProvider).loadSudokuSession(puzzleId: puzzle.id);
        localInProgress = session != null && session.elapsedSeconds > 0;
      }

      final completed = (remoteStatus?.completed ?? false) || localCompleted;
      final inProgress = !completed && ((remoteStatus?.inProgress ?? false) || localInProgress);
      final bestSeconds = remoteStatus?.bestSeconds ?? 0;

      merged[puzzle.id] = PuzzleProgressStatus(
        completed: completed,
        inProgress: inProgress,
        bestSeconds: bestSeconds,
        updatedAt: remoteStatus?.updatedAt,
      );
    }

    return (puzzles, merged);
  }

  Future<void> _openPuzzle(
    List<Puzzle> puzzles,
    int index,
    PuzzleProgressStatus? status,
  ) async {
    if (status?.completed == true) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replay solved puzzle?'),
          content: const Text('Your previous result will be replaced with this new run.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Replay'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }

    final puzzle = puzzles[index];
    switch (puzzle.type) {
      case PuzzleType.sudoku:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SudokuPage(
              puzzle: puzzle,
              puzzleSequence: puzzles,
              puzzleIndex: index,
            ),
          ),
        );
      case PuzzleType.queens:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => QueensPage(puzzle: puzzle)),
        );
      case PuzzleType.kakuro:
      case PuzzleType.nonogram:
      case PuzzleType.minesweeper:
        break;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _future = _load();
    });
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
    final inProgress = status?.inProgress ?? false;
    final leadingIcon = completed
        ? Icons.check_circle
        : (inProgress ? Icons.timelapse : Icons.radio_button_unchecked);
    final leadingColor = completed
        ? const Color(0xFF198754)
        : (inProgress ? const Color(0xFF275EA8) : const Color(0xFF8A9A92));
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
            Icon(leadingIcon, color: leadingColor),
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
            if (inProgress)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'In progress',
                  style: TextStyle(color: Color(0xFF275EA8), fontWeight: FontWeight.w700),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
