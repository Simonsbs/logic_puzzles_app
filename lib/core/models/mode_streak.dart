class ModeStreak {
  const ModeStreak({required this.basicDays, required this.proDays});

  final int basicDays;
  final int proDays;

  static const zero = ModeStreak(basicDays: 0, proDays: 0);
}
