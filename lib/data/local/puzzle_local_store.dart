import 'dart:convert';

import 'package:logic_puzzles_app/core/models/puzzle.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PuzzleLocalStore {
  Future<List<Puzzle>> loadShowcase() async {
    return <Puzzle>[
      Puzzle(
        id: 'sudoku-starter',
        type: PuzzleType.sudoku,
        title: 'Sudoku Starter',
        difficulty: 'Easy',
        publishedAt: DateTime.utc(2026, 3, 1),
        payload: <String, dynamic>{
          'grid': <List<int>>[
            <int>[0, 0, 0, 2, 6, 0, 7, 0, 1],
            <int>[6, 8, 0, 0, 7, 0, 0, 9, 0],
            <int>[1, 9, 0, 0, 0, 4, 5, 0, 0],
            <int>[8, 2, 0, 1, 0, 0, 0, 4, 0],
            <int>[0, 0, 4, 6, 0, 2, 9, 0, 0],
            <int>[0, 5, 0, 0, 0, 3, 0, 2, 8],
            <int>[0, 0, 9, 3, 0, 0, 0, 7, 4],
            <int>[0, 4, 0, 0, 5, 0, 0, 3, 6],
            <int>[7, 0, 3, 0, 1, 8, 0, 0, 0],
          ],
        },
      ),
      Puzzle(
        id: 'queens-starter',
        type: PuzzleType.queens,
        title: 'Queens Starter',
        difficulty: 'Medium',
        publishedAt: DateTime.utc(2026, 3, 1),
        payload: <String, dynamic>{
          'size': 8,
          'blocked': <List<int>>[
            <int>[0, 6],
            <int>[1, 1],
            <int>[3, 4],
            <int>[5, 2],
          ],
        },
      ),
    ];
  }

  Future<Puzzle?> loadCachedPuzzle(PuzzleType type, {bool daily = false}) async {
    final listCached = await loadCachedPuzzles(type);
    if (listCached.isNotEmpty) {
      final filtered = listCached.where((p) => p.isDaily == daily).toList();
      if (filtered.isNotEmpty) {
        return filtered.first;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final key = _cacheKey(type, daily: daily);
    final raw = prefs.getString(key);
    if (raw == null) {
      return null;
    }
    return Puzzle.fromStorageString(raw);
  }

  Future<void> cachePuzzle(Puzzle puzzle) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _cacheKey(puzzle.type, daily: puzzle.isDaily);
    await prefs.setString(key, puzzle.toStorageString());
  }

  Future<List<Puzzle>> loadCachedPuzzles(PuzzleType type) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_listCacheKey(type));
    if (raw == null) {
      return <Puzzle>[];
    }

    try {
      final list = List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
      return list.map(Puzzle.fromJson).toList();
    } catch (_) {
      return <Puzzle>[];
    }
  }

  Future<void> cachePuzzles(PuzzleType type, List<Puzzle> puzzles) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(puzzles.map((p) => p.toJson()).toList());
    await prefs.setString(_listCacheKey(type), encoded);
  }

  String _cacheKey(PuzzleType type, {required bool daily}) {
    return 'puzzle_cache_${type.name}_${daily ? 'daily' : 'regular'}';
  }

  String _listCacheKey(PuzzleType type) => 'puzzle_cache_list_${type.name}';
}
