import 'dart:convert';

import 'package:logic_puzzles_app/core/models/sudoku_session_state.dart';
import 'package:logic_puzzles_app/core/services/auth_service.dart';
import 'package:logic_puzzles_app/core/services/puzzle_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalPuzzleSessionService implements PuzzleSessionService {
  const LocalPuzzleSessionService(this._authService);

  final AuthService _authService;

  @override
  Future<SudokuSessionState?> loadSudokuSession({required String puzzleId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey(puzzleId));
    if (raw == null) {
      return null;
    }
    try {
      return SudokuSessionState.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveSudokuSession(SudokuSessionState session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey(session.puzzleId), jsonEncode(session.toJson()));
  }

  @override
  Future<void> clearSudokuSession({required String puzzleId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey(puzzleId));
  }

  String _storageKey(String puzzleId) {
    final userId = _authService.currentUser?.id ?? 'guest-local';
    return 'sudoku_session_${userId}_$puzzleId';
  }
}
