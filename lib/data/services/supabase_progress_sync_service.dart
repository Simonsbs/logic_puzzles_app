import 'package:logic_puzzles_app/core/models/user_progress.dart';
import 'package:logic_puzzles_app/core/services/progress_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProgressSyncService implements ProgressSyncService {
  const SupabaseProgressSyncService(this._client);

  final SupabaseClient _client;

  @override
  Future<void> syncProgress(UserProgress progress) async {
    await _client.auth.refreshSession();
    final user = _client.auth.currentUser;
    final session = _client.auth.currentSession;
    if (user == null || session == null) {
      throw const ProgressSyncException(
        'Please sign out and sign in again to refresh your session.',
        reasonCode: 'no_session',
      );
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
          'hints_used': progress.hintsUsed,
        },
        headers: <String, String>{
          'Authorization': 'Bearer ${session.accessToken}',
        },
      );
    } on FunctionException catch (error) {
      final parsed = _parseFunctionError(error);
      if (parsed.reasonCode == 'invalid_user_session') {
        await _client.auth.signOut();
      }
      throw ProgressSyncException(
        _reasonMessage(parsed.reasonCode, fallback: parsed.message),
        reasonCode: parsed.reasonCode ?? 'function_error',
      );
    } catch (error) {
      throw ProgressSyncException(
        'Score sync failed: ${error.toString()}',
        reasonCode: 'invoke_error',
      );
    }

    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      final map =
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final reason = map['reason_code'] as String?;
      throw ProgressSyncException(_reasonMessage(reason), reasonCode: reason);
    }
  }

  String _reasonMessage(String? reasonCode, {String? fallback}) {
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
      case 'invalid_user_session':
        return 'Session expired. You were signed out, please sign in again.';
      default:
        return fallback ?? 'Score sync failed. Please try again.';
    }
  }

  _ParsedFunctionError _parseFunctionError(FunctionException error) {
    String? reasonCode;
    String? message;

    final details = error.details;
    if (details is Map) {
      final map = Map<String, dynamic>.from(details);
      reasonCode = map['reason_code'] as String?;
      message = map['error'] as String? ?? map['message'] as String?;
    } else if (details is String && details.trim().isNotEmpty) {
      message = details;
    }

    if ((reasonCode == null || reasonCode!.isEmpty) &&
        ((error.reasonPhrase ?? '').toLowerCase().contains(
              'invalid user session',
            ) ||
            (error.details?.toString().toLowerCase().contains(
                  'invalid user session',
                ) ??
                false))) {
      reasonCode = 'invalid_user_session';
    }

    if (reasonCode == null || reasonCode.isEmpty) {
      if (error.status == 401) {
        reasonCode = 'invalid_user_session';
      } else if (error.status >= 500) {
        reasonCode = 'server_error';
      }
    }

    message ??= error.reasonPhrase ?? error.toString();
    return _ParsedFunctionError(reasonCode: reasonCode, message: message);
  }
}

class _ParsedFunctionError {
  const _ParsedFunctionError({this.reasonCode, this.message});

  final String? reasonCode;
  final String? message;
}
