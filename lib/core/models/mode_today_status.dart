class ModeTodayStatus {
  const ModeTodayStatus({
    required this.totalToday,
    required this.completedToday,
  });

  final int totalToday;
  final int completedToday;

  static const zero = ModeTodayStatus(totalToday: 0, completedToday: 0);
}
