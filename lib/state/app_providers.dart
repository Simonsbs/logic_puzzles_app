import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logic_puzzles_app/core/models/leaderboard_entry.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';
import 'package:logic_puzzles_app/core/services/auth_service.dart';
import 'package:logic_puzzles_app/core/services/leaderboard_service.dart';
import 'package:logic_puzzles_app/core/services/progress_sync_service.dart';
import 'package:logic_puzzles_app/core/services/puzzle_repository.dart';
import 'package:logic_puzzles_app/data/auth/google_auth_service.dart';
import 'package:logic_puzzles_app/data/local/puzzle_local_store.dart';
import 'package:logic_puzzles_app/data/remote/puzzle_api_client.dart';
import 'package:logic_puzzles_app/data/repositories/hybrid_puzzle_repository.dart';
import 'package:logic_puzzles_app/data/services/mock_leaderboard_service.dart';
import 'package:logic_puzzles_app/data/services/mock_progress_sync_service.dart';

final puzzleLocalStoreProvider = Provider<PuzzleLocalStore>((ref) {
  return PuzzleLocalStore();
});

final puzzleApiClientProvider = Provider<PuzzleApiClient>((ref) {
  return const PuzzleApiClient(baseUrl: 'https://api.example.com');
});

final puzzleRepositoryProvider = Provider<PuzzleRepository>((ref) {
  return HybridPuzzleRepository(
    localStore: ref.watch(puzzleLocalStoreProvider),
    apiClient: ref.watch(puzzleApiClientProvider),
  );
});

final authServiceProvider = Provider<AuthService>((ref) {
  return GoogleAuthService();
});

final progressSyncServiceProvider = Provider<ProgressSyncService>((ref) {
  return MockProgressSyncService();
});

final leaderboardServiceProvider = Provider<LeaderboardService>((ref) {
  return MockLeaderboardService();
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
