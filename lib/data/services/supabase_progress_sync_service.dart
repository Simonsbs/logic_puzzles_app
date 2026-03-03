import 'package:logic_puzzles_app/core/models/user_progress.dart';
import 'package:logic_puzzles_app/core/services/progress_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProgressSyncService implements ProgressSyncService {
  const SupabaseProgressSyncService(this._client);

  final SupabaseClient _client;

  @override
  Future<void> syncProgress(UserProgress progress) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const ProgressSyncException('Please sign in to sync progress.');
    }

    late final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'submit-score',
        body: <String, dynamic>{
          'puzzle_id': progress.puzzleId,
          'type': progress.type.name,
          'completed': progress.completed,
          'best_seconds': progress.bestSeconds,
          'streak_days': progress.streakDays,
        },
      );
    } on FunctionException catch (_) {
      throw const ProgressSyncException('Score sync failed. Please try again.');
    }

    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final reason = map['reason_code'] as String?;
      throw ProgressSyncException(_reasonMessage(reason), reasonCode: reason);
    }
  }

  String _reasonMessage(String? reasonCode) {
    switch (reasonCode) {
      case 'too_fast':
        return 'Score rejected: completion time looks unrealistic.';
      case 'rate_limit':
        return 'Too many submissions. Please wait a minute and try again.';
      case 'daily_cap':
        return 'You reached today\'s attempt cap for this puzzle.';
      case 'streak_jump':
        return 'Streak update rejected: invalid streak jump detected.';
      case 'puzzle_type_mismatch':
        return 'Submission rejected: puzzle data mismatch.';
      default:
        return 'Score sync failed. Please try again.';
    }
  }
}
