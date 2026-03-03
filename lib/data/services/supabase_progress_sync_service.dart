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
      return;
    }

    await _client.functions.invoke(
      'submit-score',
      body: <String, dynamic>{
        'puzzle_id': progress.puzzleId,
        'type': progress.type.name,
        'completed': progress.completed,
        'best_seconds': progress.bestSeconds,
        'streak_days': progress.streakDays,
      },
    );
  }
}
