import 'package:logic_puzzles_app/core/models/puzzle_progress_status.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';
import 'package:logic_puzzles_app/core/services/puzzle_progress_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabasePuzzleProgressService implements PuzzleProgressService {
  const SupabasePuzzleProgressService(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, PuzzleProgressStatus>> progressByType(PuzzleType type) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return <String, PuzzleProgressStatus>{};
    }

    try {
      final response = await _client
          .from('user_progress')
          .select('puzzle_id, completed, best_seconds, updated_at, session_elapsed_seconds')
          .eq('user_id', user.id)
          .eq('type', type.name);

      final rows = List<Map<String, dynamic>>.from(response as List);
      final map = <String, PuzzleProgressStatus>{};
      for (final row in rows) {
        final puzzleId = row['puzzle_id'] as String;
        final completed = row['completed'] as bool? ?? false;
        final elapsed = (row['session_elapsed_seconds'] as num?)?.toInt() ?? 0;
        map[puzzleId] = PuzzleProgressStatus(
          completed: completed,
          inProgress: !completed && elapsed > 0,
          bestSeconds: (row['best_seconds'] as num?)?.toInt() ?? 0,
          updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
        );
      }
      return map;
    } catch (_) {
      return <String, PuzzleProgressStatus>{};
    }
  }
}
