import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logic_puzzles_app/core/config/app_config.dart';
import 'package:logic_puzzles_app/core/models/leaderboard_entry.dart';
import 'package:logic_puzzles_app/core/models/mode_streak.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';
import 'package:logic_puzzles_app/core/services/auth_service.dart';
import 'package:logic_puzzles_app/core/services/leaderboard_service.dart';
import 'package:logic_puzzles_app/core/services/puzzle_progress_service.dart';
import 'package:logic_puzzles_app/core/services/puzzle_session_service.dart';
import 'package:logic_puzzles_app/core/services/progress_sync_service.dart';
import 'package:logic_puzzles_app/core/services/puzzle_repository.dart';
import 'package:logic_puzzles_app/data/auth/local_auth_service.dart';
import 'package:logic_puzzles_app/data/auth/supabase_auth_service.dart';
import 'package:logic_puzzles_app/data/local/puzzle_local_store.dart';
import 'package:logic_puzzles_app/data/remote/puzzle_api_client.dart';
import 'package:logic_puzzles_app/data/remote/supabase_puzzle_api_client.dart';
import 'package:logic_puzzles_app/data/repositories/hybrid_puzzle_repository.dart';
import 'package:logic_puzzles_app/data/services/mock_leaderboard_service.dart';
import 'package:logic_puzzles_app/data/services/mock_puzzle_progress_service.dart';
import 'package:logic_puzzles_app/data/services/mock_progress_sync_service.dart';
import 'package:logic_puzzles_app/data/services/local_puzzle_session_service.dart';
import 'package:logic_puzzles_app/data/services/supabase_leaderboard_service.dart';
import 'package:logic_puzzles_app/data/services/supabase_puzzle_progress_service.dart';
import 'package:logic_puzzles_app/data/services/supabase_puzzle_session_service.dart';
import 'package:logic_puzzles_app/data/services/supabase_progress_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

final puzzleLocalStoreProvider = Provider<PuzzleLocalStore>((ref) {
  return PuzzleLocalStore();
});

final puzzleApiClientProvider = Provider<PuzzleApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.supabaseEnabled) {
    return const NullPuzzleApiClient();
  }

  return SupabasePuzzleApiClient(Supabase.instance.client);
});

final puzzleRepositoryProvider = Provider<PuzzleRepository>((ref) {
  return HybridPuzzleRepository(
    localStore: ref.watch(puzzleLocalStoreProvider),
    apiClient: ref.watch(puzzleApiClientProvider),
  );
});

final authServiceProvider = Provider<AuthService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.supabaseEnabled) {
    return LocalAuthService();
  }

  return SupabaseAuthService(
    client: Supabase.instance.client,
    redirectUrl: config.supabaseAuthRedirectUrl,
  );
});

final progressSyncServiceProvider = Provider<ProgressSyncService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.supabaseEnabled) {
    return MockProgressSyncService();
  }
  return SupabaseProgressSyncService(Supabase.instance.client);
});

final puzzleProgressServiceProvider = Provider<PuzzleProgressService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.supabaseEnabled) {
    return MockPuzzleProgressService();
  }
  return SupabasePuzzleProgressService(Supabase.instance.client);
});

final puzzleSessionServiceProvider = Provider<PuzzleSessionService>((ref) {
  final auth = ref.watch(authServiceProvider);
  final config = ref.watch(appConfigProvider);
  if (!config.supabaseEnabled) {
    return LocalPuzzleSessionService(auth);
  }
  return SupabasePuzzleSessionService(
    client: Supabase.instance.client,
    authService: auth,
  );
});

final leaderboardServiceProvider = Provider<LeaderboardService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.supabaseEnabled) {
    return MockLeaderboardService();
  }
  return SupabaseLeaderboardService(Supabase.instance.client);
});

final authUserProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

final dailyHomeMessageProvider = FutureProvider<String>((ref) async {
  final config = ref.watch(appConfigProvider);
  if (!config.supabaseEnabled) {
    return _fallbackDailyMessage();
  }

  try {
    final response = await Supabase.instance.client.functions.invoke(
      'daily-content',
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final text = (data['text'] as String?)?.trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
  } catch (_) {
    // Falls back to deterministic local message.
  }
  return _fallbackDailyMessage();
});

final showcasePuzzlesProvider = FutureProvider((ref) {
  return ref.watch(puzzleRepositoryProvider).getPuzzleTypesShowcase();
});

final sudokuTypeLeaderboardProvider = FutureProvider<List<LeaderboardEntry>>((
  ref,
) {
  return ref
      .watch(leaderboardServiceProvider)
      .typeLeaderboard(PuzzleType.sudoku);
});

final queensTypeLeaderboardProvider = FutureProvider<List<LeaderboardEntry>>((
  ref,
) {
  return ref
      .watch(leaderboardServiceProvider)
      .typeLeaderboard(PuzzleType.queens);
});

final streakLeaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) {
  return ref.watch(leaderboardServiceProvider).streakLeaderboard();
});

final modeStreakProvider = FutureProvider.family<ModeStreak, PuzzleType>((
  ref,
  type,
) async {
  if (!type.isAvailableNow) {
    return ModeStreak.zero;
  }

  final puzzles = await ref.read(puzzleRepositoryProvider).getPuzzles(type);
  final remote = await ref
      .read(puzzleProgressServiceProvider)
      .progressByType(type);
  final sessionService = ref.read(puzzleSessionServiceProvider);

  final auth = ref.read(authServiceProvider);
  final userId = auth.currentUser?.id ?? 'guest-local';
  final prefs = await SharedPreferences.getInstance();

  final dayPlayed = <String, int>{};
  final dayPublishedTotals = <String, int>{};
  final dayProSolved = <String, int>{};
  final nowUtc = DateTime.now().toUtc();

  for (final puzzle in puzzles) {
    final publishedAt = puzzle.publishedAt?.toUtc();
    if (publishedAt != null) {
      final publishedKey = _dayKeyUtc(publishedAt);
      dayPublishedTotals[publishedKey] =
          (dayPublishedTotals[publishedKey] ?? 0) + 1;
    }

    final status = remote[puzzle.id];
    final localCompleted =
        prefs.getBool('puzzle_completed_${userId}_${puzzle.id}') ?? false;
    final localCompletedAtRaw = prefs.getString(
      'puzzle_completed_${userId}_${puzzle.id}_at',
    );
    final localCompletedAt =
        localCompletedAtRaw == null
            ? null
            : DateTime.tryParse(localCompletedAtRaw)?.toUtc();

    DateTime? playedAt;
    if ((status?.completed ?? false) || (status?.inProgress ?? false)) {
      playedAt = status?.updatedAt?.toUtc();
    }
    if (type == PuzzleType.sudoku) {
      final session = await sessionService.loadSudokuSession(
        puzzleId: puzzle.id,
      );
      if (session != null && session.elapsedSeconds > 0) {
        final sessionAt = session.updatedAt.toUtc();
        if (playedAt == null || sessionAt.isAfter(playedAt)) {
          playedAt = sessionAt;
        }
      }
    }
    if (localCompleted) {
      final localAt = localCompletedAt ?? nowUtc;
      if (playedAt == null || localAt.isAfter(playedAt)) {
        playedAt = localAt;
      }
    }

    if (playedAt != null) {
      final key = _dayKeyUtc(playedAt);
      dayPlayed[key] = (dayPlayed[key] ?? 0) + 1;
    }

    DateTime? completedAt;
    if (status?.completed == true && status?.updatedAt != null) {
      completedAt = status!.updatedAt!.toUtc();
    }
    if (localCompleted) {
      final localAt = localCompletedAt ?? nowUtc;
      if (completedAt == null || localAt.isAfter(completedAt)) {
        completedAt = localAt;
      }
    }

    if (completedAt != null &&
        publishedAt != null &&
        _sameUtcDay(completedAt, publishedAt)) {
      final key = _dayKeyUtc(publishedAt);
      dayProSolved[key] = (dayProSolved[key] ?? 0) + 1;
    }
  }

  final today = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);

  int basicStreak = 0;
  var cursor = today;
  while (true) {
    final key = _dayKeyUtc(cursor);
    if ((dayPlayed[key] ?? 0) <= 0) {
      break;
    }
    basicStreak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  int proStreak = 0;
  cursor = today;
  while (true) {
    final key = _dayKeyUtc(cursor);
    final total = dayPublishedTotals[key] ?? 0;
    final solved = dayProSolved[key] ?? 0;
    if (total <= 0 || solved < total) {
      break;
    }
    proStreak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return ModeStreak(basicDays: basicStreak, proDays: proStreak);
});

String _dayKeyUtc(DateTime dt) =>
    '${dt.toUtc().year}-${dt.toUtc().month.toString().padLeft(2, '0')}-${dt.toUtc().day.toString().padLeft(2, '0')}';

bool _sameUtcDay(DateTime a, DateTime b) {
  final ua = a.toUtc();
  final ub = b.toUtc();
  return ua.year == ub.year && ua.month == ub.month && ua.day == ub.day;
}

String _fallbackDailyMessage() {
  const messages = <String>[
    'Fact: Sudoku has about 6.67 sextillion valid completed grids.',
    'Joke: I solved 99 puzzles today. None of them were my life choices.',
    'Fact: The name Sudoku comes from Japanese for “single number.”',
    'Joke: I wanted an easy puzzle. The puzzle wanted character development.',
    'Fact: Logic puzzles train pattern recognition and working memory.',
    'Joke: I paused for a minute. My streak called it betrayal.',
  ];
  final today = DateTime.now().toUtc();
  final index =
      today.difference(DateTime.utc(2026, 1, 1)).inDays.abs() % messages.length;
  return messages[index];
}
