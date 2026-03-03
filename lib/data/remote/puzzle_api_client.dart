import 'package:logic_puzzles_app/core/models/puzzle.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';

class PuzzleApiClient {
  const PuzzleApiClient({required this.baseUrl});

  final String baseUrl;

  Future<Puzzle?> fetchPuzzle(PuzzleType type, {required bool daily}) async {
    // TODO: replace with a real endpoint call. Keep nullable for offline fallback.
    return null;
  }
}
