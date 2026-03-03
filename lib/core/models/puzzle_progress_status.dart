class PuzzleProgressStatus {
  const PuzzleProgressStatus({
    required this.completed,
    required this.bestSeconds,
    this.updatedAt,
  });

  final bool completed;
  final int bestSeconds;
  final DateTime? updatedAt;
}
