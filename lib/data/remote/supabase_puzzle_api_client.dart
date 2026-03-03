import 'package:logic_puzzles_app/core/models/puzzle.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';
import 'package:logic_puzzles_app/data/remote/puzzle_api_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabasePuzzleApiClient implements PuzzleApiClient {
  const SupabasePuzzleApiClient(this._client);

  final SupabaseClient _client;

  @override
  Future<Puzzle?> fetchPuzzle(PuzzleType type, {required bool daily}) async {
    try {
      final response = await _client
          .from('puzzles')
          .select('id, type, title, difficulty, payload, is_daily')
          .eq('type', type.name)
          .eq('is_daily', daily)
          .order('published_at', ascending: false)
          .limit(1);

      final rows = List<Map<String, dynamic>>.from(response as List);
      if (rows.isEmpty) {
        return null;
      }

      return Puzzle.fromJson(rows.first);
    } catch (_) {
      return null;
    }
  }
}
