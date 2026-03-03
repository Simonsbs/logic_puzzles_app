import 'package:logic_puzzles_app/core/models/sudoku_session_state.dart';

abstract class PuzzleSessionService {
  Future<SudokuSessionState?> loadSudokuSession({required String puzzleId});
  Future<void> saveSudokuSession(SudokuSessionState session);
  Future<void> clearSudokuSession({required String puzzleId});
}
