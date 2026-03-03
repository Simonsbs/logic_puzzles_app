import 'package:logic_puzzles_app/core/models/puzzle_progress_status.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';

abstract class PuzzleProgressService {
  Future<Map<String, PuzzleProgressStatus>> progressByType(PuzzleType type);
}
