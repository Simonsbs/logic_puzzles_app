import 'package:logic_puzzles_app/core/models/leaderboard_entry.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';
import 'package:logic_puzzles_app/core/services/leaderboard_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseLeaderboardService implements LeaderboardService {
  const SupabaseLeaderboardService(this._client);

  final SupabaseClient _client;

  @override
  Future<List<LeaderboardEntry>> puzzleLeaderboard(String puzzleId) async {
    try {
      final rows = await _client
          .from('leaderboard_puzzle')
          .select('rank, user_name, score, label')
          .eq('puzzle_id', puzzleId)
          .order('rank', ascending: true)
          .limit(20);
      return _parseRows(rows);
    } catch (_) {
      return <LeaderboardEntry>[];
    }
  }

  @override
  Future<List<LeaderboardEntry>> streakLeaderboard() async {
    try {
      final rows = await _client
          .from('leaderboard_streak')
          .select('rank, user_name, score, label')
          .order('rank', ascending: true)
          .limit(20);
      return _parseRows(rows);
    } catch (_) {
      return <LeaderboardEntry>[];
    }
  }

  @override
  Future<List<LeaderboardEntry>> typeLeaderboard(PuzzleType type) async {
    try {
      final rows = await _client
          .from('leaderboard_type')
          .select('rank, user_name, score, label')
          .eq('type', type.name)
          .order('rank', ascending: true)
          .limit(20);
      return _parseRows(rows);
    } catch (_) {
      return <LeaderboardEntry>[];
    }
  }

  List<LeaderboardEntry> _parseRows(dynamic response) {
    final rows = List<Map<String, dynamic>>.from(response as List);
    return rows
        .map(
          (row) => LeaderboardEntry(
            rank: _toInt(row['rank']),
            userName:
                (row['user_name'] as String?)?.trim().isNotEmpty == true
                    ? row['user_name'] as String
                    : 'Player',
            score: _toInt(row['score']),
            label:
                (row['label'] as String?)?.trim().isNotEmpty == true
                    ? row['label'] as String
                    : 'pts',
          ),
        )
        .toList();
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}
