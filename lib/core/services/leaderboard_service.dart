import 'package:logic_puzzles_app/core/models/leaderboard_entry.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';

abstract class LeaderboardService {
  Future<List<LeaderboardEntry>> typeLeaderboard(PuzzleType type);
  Future<List<LeaderboardEntry>> puzzleLeaderboard(String puzzleId);
  Future<List<LeaderboardEntry>> streakLeaderboard();
}
