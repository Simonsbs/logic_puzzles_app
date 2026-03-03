import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logic_puzzles_app/core/models/puzzle.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';
import 'package:logic_puzzles_app/core/models/user_progress.dart';
import 'package:logic_puzzles_app/core/services/progress_sync_service.dart';
import 'package:logic_puzzles_app/state/app_providers.dart';

class SudokuPage extends ConsumerStatefulWidget {
  const SudokuPage({super.key});

  @override
  ConsumerState<SudokuPage> createState() => _SudokuPageState();
}

class _SudokuPageState extends ConsumerState<SudokuPage> with WidgetsBindingObserver {
  bool _initialized = false;
  bool _paused = false;
  bool _pencilMode = false;
  bool _solved = false;

  int _elapsedSeconds = 0;
  int _hintsUsed = 0;

  int? _selectedRow;
  int? _selectedCol;

  late Puzzle _puzzle;
  late List<List<int>> _initialGrid;
  late List<List<int>> _board;
  late List<List<int>> _solution;
  late Set<String> _fixedCells;
  Map<String, Set<int>> _pencilMarks = <String, Set<int>>{};

  final List<_SudokuSnapshot> _history = <_SudokuSnapshot>[];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _pauseGame();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sudoku')),
      body: FutureBuilder<Puzzle>(
        future: ref.read(puzzleRepositoryProvider).getPuzzle(PuzzleType.sudoku, daily: true),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!_initialized) {
            _setupGame(snapshot.data!);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _statusAndControls(),
              const SizedBox(height: 12),
              _boardCard(),
              const SizedBox(height: 12),
              _numberPad(),
              const SizedBox(height: 10),
              _actionRow(),
            ],
          );
        },
      ),
    );
  }

  Widget _statusAndControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              _pill('Time: ${_formatTime(_elapsedSeconds)}'),
              _pill('Hints: $_hintsUsed'),
              _pill(_pencilMode ? 'Pencil ON' : 'Pencil OFF'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _paused ? _resumeGame : _pauseGame,
                  icon: Icon(_paused ? Icons.play_arrow : Icons.pause, size: 18),
                  label: Text(_paused ? 'Resume' : 'Pause'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _solved || _paused
                      ? null
                      : () {
                          setState(() => _pencilMode = !_pencilMode);
                        },
                  icon: Icon(_pencilMode ? Icons.edit_note : Icons.edit_outlined, size: 18),
                  label: const Text('Pencil'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _solved || _paused ? null : _useHint,
                  icon: const Icon(Icons.lightbulb, size: 18),
                  label: const Text('Hint'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6F2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Widget _boardCard() {
    final conflictCells = _conflictingCells();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          children: <Widget>[
            Table(
              defaultColumnWidth: const FlexColumnWidth(),
              children: List<TableRow>.generate(9, (row) {
                return TableRow(
                  children: List<Widget>.generate(9, (col) {
                    return AspectRatio(
                      aspectRatio: 1,
                      child: _buildCell(row, col, conflictCells),
                    );
                  }),
                );
              }),
            ),
            if (_paused)
              Positioned.fill(
                child: Container(
                  color: const Color(0xE0111519),
                  child: const Center(
                    child: Text(
                      'Paused',
                      style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col, Set<String> conflictCells) {
    final key = _cellKey(row, col);
    final value = _board[row][col];
    final selected = _selectedRow == row && _selectedCol == col;
    final fixed = _fixedCells.contains(key);
    final hasConflict = conflictCells.contains(key);

    final selectedValue = (_selectedRow != null && _selectedCol != null)
        ? _board[_selectedRow!][_selectedCol!]
        : 0;
    final sameValue = selectedValue != 0 && value == selectedValue;

    final boxShade = ((row ~/ 3) + (col ~/ 3)).isEven;
    Color background = boxShade ? const Color(0xFFF7FBF8) : const Color(0xFFEDF4F0);

    if (fixed) {
      background = const Color(0xFFE2ECE7);
    }
    if (sameValue) {
      background = const Color(0xFFD9F2E7);
    }
    if (hasConflict) {
      background = const Color(0xFFF8D4D4);
    }
    if (selected) {
      background = hasConflict ? const Color(0xFFF2A9A9) : const Color(0xFFBDE7D1);
    }

    final border = Border(
      left: BorderSide(
        width: col == 0
            ? 2.2
            : (col % 3 == 0 ? 1.8 : 0.7),
        color: const Color(0xFF5A6B64),
      ),
      top: BorderSide(
        width: row == 0
            ? 2.2
            : (row % 3 == 0 ? 1.8 : 0.7),
        color: const Color(0xFF5A6B64),
      ),
      right: BorderSide(width: col == 8 ? 2.2 : 0, color: const Color(0xFF5A6B64)),
      bottom: BorderSide(width: row == 8 ? 2.2 : 0, color: const Color(0xFF5A6B64)),
    );

    return GestureDetector(
      onTap: _paused || _solved
          ? null
          : () {
              setState(() {
                _selectedRow = row;
                _selectedCol = col;
              });
            },
      child: Container(
        decoration: BoxDecoration(color: background, border: border),
        child: value != 0
            ? Center(
                child: Text(
                  '$value',
                  style: TextStyle(
                    fontWeight: fixed ? FontWeight.w800 : FontWeight.w700,
                    fontSize: 24,
                    color: hasConflict
                        ? const Color(0xFF8B1C1C)
                        : (fixed ? const Color(0xFF2E3A35) : const Color(0xFF0D6144)),
                  ),
                ),
              )
            : _buildPencilMarks(row, col),
      ),
    );
  }

  Widget _buildPencilMarks(int row, int col) {
    final marks = _pencilMarks[_cellKey(row, col)] ?? <int>{};
    if (marks.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      padding: const EdgeInsets.all(2),
      children: List<Widget>.generate(9, (i) {
        final n = i + 1;
        return Center(
          child: Text(
            marks.contains(n) ? '$n' : '',
            style: const TextStyle(fontSize: 10, color: Color(0xFF46695C), fontWeight: FontWeight.w700),
          ),
        );
      }),
    );
  }

  Widget _numberPad() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 2.2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: List<Widget>.generate(9, (i) {
        final n = i + 1;
        return FilledButton.tonal(
          onPressed: _paused || _solved ? null : () => _applyNumber(n),
          style: FilledButton.styleFrom(padding: EdgeInsets.zero, textStyle: const TextStyle(fontSize: 22)),
          child: Text('$n', style: const TextStyle(fontWeight: FontWeight.w800)),
        );
      }),
    );
  }

  Widget _actionRow() {
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _paused || _solved ? null : _clearSelected,
            icon: const Icon(Icons.backspace_outlined),
            label: const Text('Clear cell'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _paused || _solved || _history.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo),
            label: const Text('Undo'),
          ),
        ),
      ],
    );
  }

  void _setupGame(Puzzle puzzle) {
    _puzzle = puzzle;
    _initialGrid = (puzzle.payload['grid'] as List)
        .map((row) => List<int>.from(row as List))
        .toList();
    _board = _copyGrid(_initialGrid);
    _solution = _solveSudoku(_copyGrid(_initialGrid));

    _fixedCells = <String>{};
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (_initialGrid[r][c] != 0) {
          _fixedCells.add(_cellKey(r, c));
        }
      }
    }

    _startTimer();
    _initialized = true;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paused || _solved) {
        return;
      }
      setState(() => _elapsedSeconds++);
    });
  }

  void _pauseGame() {
    setState(() => _paused = true);
  }

  void _resumeGame() {
    setState(() => _paused = false);
  }

  void _applyNumber(int value) {
    if (_selectedRow == null || _selectedCol == null) {
      return;
    }
    final row = _selectedRow!;
    final col = _selectedCol!;
    if (_fixedCells.contains(_cellKey(row, col))) {
      return;
    }

    _pushHistory();

    if (_pencilMode) {
      final key = _cellKey(row, col);
      final marks = Set<int>.from(_pencilMarks[key] ?? <int>{});
      if (marks.contains(value)) {
        marks.remove(value);
      } else {
        marks.add(value);
      }
      _pencilMarks[key] = marks;
      setState(() {});
      return;
    }

    _board[row][col] = value;
    _pencilMarks.remove(_cellKey(row, col));
    _removeValueFromPeers(row, col, value);

    setState(() {});
    _checkSolved();
  }

  void _clearSelected() {
    if (_selectedRow == null || _selectedCol == null) {
      return;
    }
    final row = _selectedRow!;
    final col = _selectedCol!;
    if (_fixedCells.contains(_cellKey(row, col))) {
      return;
    }

    _pushHistory();
    _board[row][col] = 0;
    _pencilMarks.remove(_cellKey(row, col));
    setState(() {});
  }

  void _undo() {
    if (_history.isEmpty) {
      return;
    }
    final last = _history.removeLast();
    setState(() {
      _board = _copyGrid(last.board);
      _pencilMarks = last.pencilMarks.map((k, v) => MapEntry(k, Set<int>.from(v)));
      _hintsUsed = last.hintsUsed;
    });
  }

  void _useHint() {
    _pushHistory();

    int? targetRow = _selectedRow;
    int? targetCol = _selectedCol;

    if (targetRow == null || targetCol == null || _board[targetRow][targetCol] != 0) {
      final firstEmpty = _findFirstEmpty();
      if (firstEmpty == null) {
        return;
      }
      targetRow = firstEmpty.$1;
      targetCol = firstEmpty.$2;
      _selectedRow = targetRow;
      _selectedCol = targetCol;
    }

    _board[targetRow][targetCol] = _solution[targetRow][targetCol];
    _pencilMarks.remove(_cellKey(targetRow, targetCol));
    _removeValueFromPeers(targetRow, targetCol, _solution[targetRow][targetCol]);
    _hintsUsed++;
    setState(() {});
    _checkSolved();
  }

  (int, int)? _findFirstEmpty() {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (_board[r][c] == 0) {
          return (r, c);
        }
      }
    }
    return null;
  }

  void _removeValueFromPeers(int row, int col, int value) {
    for (var i = 0; i < 9; i++) {
      _pencilMarks[_cellKey(row, i)]?.remove(value);
      _pencilMarks[_cellKey(i, col)]?.remove(value);
    }

    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (var r = boxRow; r < boxRow + 3; r++) {
      for (var c = boxCol; c < boxCol + 3; c++) {
        _pencilMarks[_cellKey(r, c)]?.remove(value);
      }
    }
  }

  void _checkSolved() {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (_board[r][c] != _solution[r][c]) {
          return;
        }
      }
    }

    _timer?.cancel();
    _solved = true;
    _syncCompletion();
  }

  Future<void> _syncCompletion() async {
    try {
      await ref.read(progressSyncServiceProvider).syncProgress(
            UserProgress(
              puzzleId: _puzzle.id,
              type: PuzzleType.sudoku,
              completed: true,
              bestSeconds: _elapsedSeconds,
              streakDays: 5,
              hintsUsed: _hintsUsed,
            ),
          );
    } on ProgressSyncException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }

    if (!mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Puzzle solved'),
        content: Text('Time: ${_formatTime(_elapsedSeconds)}\nHints used: $_hintsUsed'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Nice'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _cellKey(int row, int col) => '$row:$col';

  void _pushHistory() {
    _history.add(
      _SudokuSnapshot(
        board: _copyGrid(_board),
        pencilMarks: _pencilMarks.map((k, v) => MapEntry(k, Set<int>.from(v))),
        hintsUsed: _hintsUsed,
      ),
    );
  }

  List<List<int>> _copyGrid(List<List<int>> grid) {
    return grid.map((row) => List<int>.from(row)).toList();
  }

  List<List<int>> _solveSudoku(List<List<int>> grid) {
    bool solve() {
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if (grid[r][c] == 0) {
            for (var n = 1; n <= 9; n++) {
              if (_canPlace(grid, r, c, n)) {
                grid[r][c] = n;
                if (solve()) {
                  return true;
                }
                grid[r][c] = 0;
              }
            }
            return false;
          }
        }
      }
      return true;
    }

    final solved = solve();
    if (!solved) {
      throw StateError('Sudoku puzzle has no valid solution');
    }
    return grid;
  }

  bool _canPlace(List<List<int>> grid, int row, int col, int value) {
    for (var i = 0; i < 9; i++) {
      if (grid[row][i] == value || grid[i][col] == value) {
        return false;
      }
    }

    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (var r = boxRow; r < boxRow + 3; r++) {
      for (var c = boxCol; c < boxCol + 3; c++) {
        if (grid[r][c] == value) {
          return false;
        }
      }
    }

    return true;
  }

  Set<String> _conflictingCells() {
    final conflicts = <String>{};

    for (var row = 0; row < 9; row++) {
      final byValue = <int, List<int>>{};
      for (var col = 0; col < 9; col++) {
        final value = _board[row][col];
        if (value == 0) {
          continue;
        }
        byValue.putIfAbsent(value, () => <int>[]).add(col);
      }
      byValue.forEach((_, cols) {
        if (cols.length > 1) {
          for (final col in cols) {
            conflicts.add(_cellKey(row, col));
          }
        }
      });
    }

    for (var col = 0; col < 9; col++) {
      final byValue = <int, List<int>>{};
      for (var row = 0; row < 9; row++) {
        final value = _board[row][col];
        if (value == 0) {
          continue;
        }
        byValue.putIfAbsent(value, () => <int>[]).add(row);
      }
      byValue.forEach((_, rows) {
        if (rows.length > 1) {
          for (final row in rows) {
            conflicts.add(_cellKey(row, col));
          }
        }
      });
    }

    for (var boxRow = 0; boxRow < 3; boxRow++) {
      for (var boxCol = 0; boxCol < 3; boxCol++) {
        final byValue = <int, List<(int, int)>>{};
        for (var r = boxRow * 3; r < boxRow * 3 + 3; r++) {
          for (var c = boxCol * 3; c < boxCol * 3 + 3; c++) {
            final value = _board[r][c];
            if (value == 0) {
              continue;
            }
            byValue.putIfAbsent(value, () => <(int, int)>[]).add((r, c));
          }
        }
        byValue.forEach((_, cells) {
          if (cells.length > 1) {
            for (final cell in cells) {
              conflicts.add(_cellKey(cell.$1, cell.$2));
            }
          }
        });
      }
    }

    return conflicts;
  }
}

class _SudokuSnapshot {
  const _SudokuSnapshot({required this.board, required this.pencilMarks, required this.hintsUsed});

  final List<List<int>> board;
  final Map<String, Set<int>> pencilMarks;
  final int hintsUsed;
}
