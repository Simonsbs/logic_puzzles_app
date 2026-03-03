class PuzzleProgressStatus {
  const PuzzleProgressStatus({
    required this.completed,
    required this.inProgress,
    required this.bestSeconds,
    this.updatedAt,
  });

  final bool completed;
  final bool inProgress;
  final int bestSeconds;
  final DateTime? updatedAt;
}
