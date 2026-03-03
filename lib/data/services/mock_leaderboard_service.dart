import 'package:logic_puzzles_app/core/models/leaderboard_entry.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';
import 'package:logic_puzzles_app/core/services/leaderboard_service.dart';

class MockLeaderboardService implements LeaderboardService {
  @override
  Future<List<LeaderboardEntry>> puzzleLeaderboard(String puzzleId) async {
    return _sample('Puzzle', offset: puzzleId.hashCode % 10);
  }

  @override
  Future<List<LeaderboardEntry>> streakLeaderboard() async {
    return <LeaderboardEntry>[
      const LeaderboardEntry(rank: 1, userName: 'Lena', score: 142, label: 'day streak'),
      const LeaderboardEntry(rank: 2, userName: 'Aron', score: 116, label: 'day streak'),
      const LeaderboardEntry(rank: 3, userName: 'Mika', score: 89, label: 'day streak'),
    ];
  }

  @override
  Future<List<LeaderboardEntry>> typeLeaderboard(PuzzleType type) async {
    return _sample(type.displayName, offset: type.index);
  }

  List<LeaderboardEntry> _sample(String label, {required int offset}) {
    return <LeaderboardEntry>[
      LeaderboardEntry(rank: 1, userName: 'Player A', score: 1200 - offset, label: '$label score'),
      LeaderboardEntry(rank: 2, userName: 'Player B', score: 1140 - offset, label: '$label score'),
      LeaderboardEntry(rank: 3, userName: 'Player C', score: 980 - offset, label: '$label score'),
    ];
  }
}
