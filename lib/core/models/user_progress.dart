import 'package:logic_puzzles_app/core/models/puzzle_type.dart';

class UserProgress {
  const UserProgress({
    required this.puzzleId,
    required this.type,
    required this.completed,
    required this.bestSeconds,
    required this.streakDays,
    this.hintsUsed = 0,
  });

  final String puzzleId;
  final PuzzleType type;
  final bool completed;
  final int bestSeconds;
  final int streakDays;
  final int hintsUsed;
}
