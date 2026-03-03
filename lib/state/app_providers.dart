import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logic_puzzles_app/core/config/app_config.dart';
import 'package:logic_puzzles_app/core/models/leaderboard_entry.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';
import 'package:logic_puzzles_app/core/services/auth_service.dart';
import 'package:logic_puzzles_app/core/services/leaderboard_service.dart';
import 'package:logic_puzzles_app/core/services/progress_sync_service.dart';
import 'package:logic_puzzles_app/core/services/puzzle_repository.dart';
import 'package:logic_puzzles_app/data/auth/local_auth_service.dart';
import 'package:logic_puzzles_app/data/auth/supabase_auth_service.dart';
import 'package:logic_puzzles_app/data/local/puzzle_local_store.dart';
import 'package:logic_puzzles_app/data/remote/puzzle_api_client.dart';
import 'package:logic_puzzles_app/data/remote/supabase_puzzle_api_client.dart';
import 'package:logic_puzzles_app/data/repositories/hybrid_puzzle_repository.dart';
import 'package:logic_puzzles_app/data/services/mock_leaderboard_service.dart';
import 'package:logic_puzzles_app/data/services/mock_progress_sync_service.dart';
import 'package:logic_puzzles_app/data/services/supabase_leaderboard_service.dart';
import 'package:logic_puzzles_app/data/services/supabase_progress_sync_service.dart';
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

final sudokuTypeLeaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) {
  return ref.watch(leaderboardServiceProvider).typeLeaderboard(PuzzleType.sudoku);
});

final queensTypeLeaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) {
  return ref.watch(leaderboardServiceProvider).typeLeaderboard(PuzzleType.queens);
});

final streakLeaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) {
  return ref.watch(leaderboardServiceProvider).streakLeaderboard();
});
