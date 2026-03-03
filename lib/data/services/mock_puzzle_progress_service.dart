import 'package:logic_puzzles_app/core/models/puzzle_progress_status.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';
import 'package:logic_puzzles_app/core/services/puzzle_progress_service.dart';

class MockPuzzleProgressService implements PuzzleProgressService {
  @override
  Future<Map<String, PuzzleProgressStatus>> progressByType(PuzzleType type) async {
    return <String, PuzzleProgressStatus>{};
  }
}
