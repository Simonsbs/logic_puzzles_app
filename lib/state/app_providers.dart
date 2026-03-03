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

  final mergedSolved = Map<String, bool>.fromEntries(
    puzzles.map((p) => MapEntry(p.id, remote[p.id]?.completed ?? false)),
  );
  final mergedPlayed = Map<String, bool>.fromEntries(
    puzzles.map(
      (p) => MapEntry(
        p.id,
        (remote[p.id]?.completed ?? false) ||
            (remote[p.id]?.inProgress ?? false),
      ),
    ),
  );

  for (final puzzle in puzzles) {
    final localCompleted =
        prefs.getBool('puzzle_completed_${userId}_${puzzle.id}') ?? false;
    if (localCompleted) {
      mergedSolved[puzzle.id] = true;
      mergedPlayed[puzzle.id] = true;
    }
    if (type == PuzzleType.sudoku) {
      final session = await sessionService.loadSudokuSession(
        puzzleId: puzzle.id,
      );
      if (session != null && session.elapsedSeconds > 0) {
        mergedPlayed[puzzle.id] = true;
      }
    }
  }

  final dayTotals = <String, int>{};
  final daySolved = <String, int>{};
  final dayPlayed = <String, int>{};

  for (final puzzle in puzzles) {
    final published = puzzle.publishedAt ?? DateTime.now().toUtc();
    final dayKey = _dayKeyUtc(published);
    dayTotals[dayKey] = (dayTotals[dayKey] ?? 0) + 1;
    if (mergedSolved[puzzle.id] == true) {
      daySolved[dayKey] = (daySolved[dayKey] ?? 0) + 1;
    }
    if (mergedPlayed[puzzle.id] == true) {
      dayPlayed[dayKey] = (dayPlayed[dayKey] ?? 0) + 1;
    }
  }

  final dates =
      dayTotals.keys
          .map(_dateFromKey)
          .where(
            (d) =>
                d.isBefore(DateTime.now().toUtc().add(const Duration(days: 1))),
          )
          .toList()
        ..sort((a, b) => b.compareTo(a));

  if (dates.isEmpty) {
    return ModeStreak.zero;
  }

  final start = dates.first;

  int compute(bool pro) {
    var streak = 0;
    var cursor = start;
    while (true) {
      final key = _dayKeyUtc(cursor);
      final total = dayTotals[key] ?? 0;
      final solved = daySolved[key] ?? 0;
      final played = dayPlayed[key] ?? 0;
      final hit = pro ? (total > 0 && solved >= total) : (played > 0);
      if (!hit) {
        break;
      }
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  return ModeStreak(basicDays: compute(false), proDays: compute(true));
});

String _dayKeyUtc(DateTime dt) =>
    '${dt.toUtc().year}-${dt.toUtc().month.toString().padLeft(2, '0')}-${dt.toUtc().day.toString().padLeft(2, '0')}';

DateTime _dateFromKey(String key) {
  final parts = key.split('-').map(int.parse).toList(growable: false);
  return DateTime.utc(parts[0], parts[1], parts[2]);
}
