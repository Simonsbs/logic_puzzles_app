enum PuzzleType {
  sudoku,
  queens,
  kakuro,
  nonogram,
  minesweeper,
}

extension PuzzleTypeX on PuzzleType {
  String get displayName {
    switch (this) {
      case PuzzleType.sudoku:
        return 'Sudoku';
      case PuzzleType.queens:
        return 'Queens';
      case PuzzleType.kakuro:
        return 'Kakuro';
      case PuzzleType.nonogram:
        return 'Nonogram';
      case PuzzleType.minesweeper:
        return 'Minesweeper';
    }
  }

  bool get isAvailableNow {
    return this == PuzzleType.sudoku || this == PuzzleType.queens;
  }
}
