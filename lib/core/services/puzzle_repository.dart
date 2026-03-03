import 'package:logic_puzzles_app/core/models/puzzle.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';

abstract class PuzzleRepository {
  Future<List<Puzzle>> getPuzzleTypesShowcase();
  Future<List<Puzzle>> getPuzzles(PuzzleType type);
  Future<Puzzle> getPuzzle(PuzzleType type, {bool daily = false});
}
