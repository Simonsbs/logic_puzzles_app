import 'package:logic_puzzles_app/core/models/puzzle_type.dart';

class UserProgress {
  const UserProgress({
    required this.puzzleId,
    required this.type,
    required this.completed,
    required this.bestSeconds,
    required this.streakDays,
  });

  final String puzzleId;
  final PuzzleType type;
  final bool completed;
  final int bestSeconds;
  final int streakDays;
}
