import 'package:logic_puzzles_app/core/models/puzzle.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';
import 'package:logic_puzzles_app/core/services/puzzle_repository.dart';
import 'package:logic_puzzles_app/data/local/puzzle_local_store.dart';
import 'package:logic_puzzles_app/data/remote/puzzle_api_client.dart';

class HybridPuzzleRepository implements PuzzleRepository {
  const HybridPuzzleRepository({required this.localStore, required this.apiClient});

  final PuzzleLocalStore localStore;
  final PuzzleApiClient apiClient;

  @override
  Future<List<Puzzle>> getPuzzleTypesShowcase() {
    return localStore.loadShowcase();
  }

  @override
  Future<List<Puzzle>> getPuzzles(PuzzleType type) async {
    final remote = await apiClient.fetchPuzzles(type);
    if (remote.isNotEmpty) {
      await localStore.cachePuzzles(type, remote);
      return remote;
    }

    final cached = await localStore.loadCachedPuzzles(type);
    if (cached.isNotEmpty) {
      return cached;
    }

    final showcase = await localStore.loadShowcase();
    return showcase.where((p) => p.type == type).toList();
  }

  @override
  Future<Puzzle> getPuzzle(PuzzleType type, {bool daily = false}) async {
    final remote = await apiClient.fetchPuzzle(type, daily: daily);
    if (remote != null) {
      await localStore.cachePuzzle(remote);
      return remote;
    }

    final cached = await localStore.loadCachedPuzzle(type, daily: daily);
    if (cached != null) {
      return cached;
    }

    final puzzles = await getPuzzles(type);
    if (puzzles.isNotEmpty) {
      return puzzles.first;
    }

    final showcase = await localStore.loadShowcase();
    return showcase.firstWhere((p) => p.type == type);
  }
}
