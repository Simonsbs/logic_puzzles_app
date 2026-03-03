class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.userName,
    required this.score,
    required this.label,
  });

  final int rank;
  final String userName;
  final int score;
  final String label;
}
