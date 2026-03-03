import 'package:logic_puzzles_app/core/models/sudoku_session_state.dart';
import 'package:logic_puzzles_app/core/services/auth_service.dart';
import 'package:logic_puzzles_app/core/services/puzzle_session_service.dart';
import 'package:logic_puzzles_app/data/services/local_puzzle_session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabasePuzzleSessionService implements PuzzleSessionService {
  SupabasePuzzleSessionService({required SupabaseClient client, required AuthService authService})
      : _client = client,
        _local = LocalPuzzleSessionService(authService);

  final SupabaseClient _client;
  final LocalPuzzleSessionService _local;

  @override
  Future<SudokuSessionState?> loadSudokuSession({required String puzzleId}) async {
    final local = await _local.loadSudokuSession(puzzleId: puzzleId);
    final user = _client.auth.currentUser;
    if (user == null) {
      return local;
    }

    try {
      final response = await _client
          .from('user_progress')
          .select('session_state, session_elapsed_seconds, session_updated_at')
          .eq('user_id', user.id)
          .eq('puzzle_id', puzzleId)
          .maybeSingle();

      if (response == null || response['session_state'] == null) {
        return local;
      }

      final state = Map<String, dynamic>.from(response['session_state'] as Map);
      state['elapsedSeconds'] = (response['session_elapsed_seconds'] as num?)?.toInt() ?? 0;
      state['updatedAt'] = response['session_updated_at'] as String? ?? DateTime.now().toUtc().toIso8601String();
      if (state['puzzleId'] == null) {
        state['puzzleId'] = puzzleId;
      }

      final remote = SudokuSessionState.fromJson(state);
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        await _local.saveSudokuSession(remote);
        return remote;
      }

      if (local.updatedAt.isAfter(remote.updatedAt)) {
        await saveSudokuSession(local);
      }
      return local;
    } catch (_) {
      return local;
    }
  }

  @override
  Future<void> saveSudokuSession(SudokuSessionState session) async {
    await _local.saveSudokuSession(session);

    final user = _client.auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      await _client.functions.invoke(
        'save-puzzle-session',
        body: <String, dynamic>{
          'puzzle_id': session.puzzleId,
          'type': 'sudoku',
          'elapsed_seconds': session.elapsedSeconds,
          'session_state': session.toJson(),
          'session_updated_at': session.updatedAt.toUtc().toIso8601String(),
          'clear': false,
        },
      );
    } catch (_) {
      // Keep local state for offline continuity.
    }
  }

  @override
  Future<void> clearSudokuSession({required String puzzleId}) async {
    await _local.clearSudokuSession(puzzleId: puzzleId);

    final user = _client.auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      await _client.functions.invoke(
        'save-puzzle-session',
        body: <String, dynamic>{
          'puzzle_id': puzzleId,
          'type': 'sudoku',
          'clear': true,
        },
      );
    } catch (_) {
      // Best-effort remote clear.
    }
  }
}
