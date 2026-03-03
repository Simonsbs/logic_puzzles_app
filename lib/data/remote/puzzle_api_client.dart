import 'package:logic_puzzles_app/core/models/puzzle.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';

abstract class PuzzleApiClient {
  Future<Puzzle?> fetchPuzzle(PuzzleType type, {required bool daily});
  Future<List<Puzzle>> fetchPuzzles(PuzzleType type);
}

class NullPuzzleApiClient implements PuzzleApiClient {
  const NullPuzzleApiClient();

  @override
  Future<Puzzle?> fetchPuzzle(PuzzleType type, {required bool daily}) async {
    return null;
  }

  @override
  Future<List<Puzzle>> fetchPuzzles(PuzzleType type) async {
    return <Puzzle>[];
  }
}
