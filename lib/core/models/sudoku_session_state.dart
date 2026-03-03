class SudokuSessionState {
  const SudokuSessionState({
    required this.puzzleId,
    required this.board,
    required this.pencilMarks,
    required this.hintsUsed,
    required this.elapsedSeconds,
    required this.updatedAt,
  });

  final String puzzleId;
  final List<List<int>> board;
  final Map<String, Set<int>> pencilMarks;
  final int hintsUsed;
  final int elapsedSeconds;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'puzzleId': puzzleId,
      'board': board,
      'pencilMarks': pencilMarks.map((key, value) => MapEntry(key, value.toList()..sort())),
      'hintsUsed': hintsUsed,
      'elapsedSeconds': elapsedSeconds,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory SudokuSessionState.fromJson(Map<String, dynamic> json) {
    final boardRaw = (json['board'] as List)
        .map((row) => List<int>.from(row as List))
        .toList();

    final marksRaw = Map<String, dynamic>.from(json['pencilMarks'] as Map? ?? <String, dynamic>{});
    final marks = <String, Set<int>>{};
    for (final entry in marksRaw.entries) {
      marks[entry.key] = Set<int>.from(List<int>.from(entry.value as List));
    }

    return SudokuSessionState(
      puzzleId: json['puzzleId'] as String,
      board: boardRaw,
      pencilMarks: marks,
      hintsUsed: (json['hintsUsed'] as num?)?.toInt() ?? 0,
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toUtc() ?? DateTime.now().toUtc(),
    );
  }
}
