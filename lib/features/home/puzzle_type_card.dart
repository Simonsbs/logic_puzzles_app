import 'package:flutter/material.dart';
import 'package:logic_puzzles_app/core/models/mode_streak.dart';
import 'package:logic_puzzles_app/core/models/mode_today_status.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';

class PuzzleTypeCard extends StatelessWidget {
  const PuzzleTypeCard({
    super.key,
    required this.type,
    required this.onTap,
    this.streak,
    this.todayStatus = ModeTodayStatus.zero,
  });

  final PuzzleType type;
  final VoidCallback onTap;
  final ModeStreak? streak;
  final ModeTodayStatus todayStatus;

  @override
  Widget build(BuildContext context) {
    final available = type.isAvailableNow;
    final accent =
        available ? const Color(0xFF0D8A63) : const Color(0xFFCC8A17);
    final icon = _iconForType(type);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x14000000)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        type.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        available
                            ? _todayStatusLabel(todayStatus)
                            : 'Coming soon',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (available && streak != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.local_fire_department_rounded,
                              size: 14,
                              color: Color(0xFFB26A00),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${streak!.basicDays}',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF3D5A4F),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.workspace_premium_rounded,
                              size: 14,
                              color: Color(0xFF198754),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${streak!.proDays}',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF3D5A4F),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForType(PuzzleType type) {
    switch (type) {
      case PuzzleType.sudoku:
        return Icons.grid_on_rounded;
      case PuzzleType.queens:
        return Icons.workspace_premium_rounded;
      case PuzzleType.kakuro:
        return Icons.calculate_rounded;
      case PuzzleType.nonogram:
        return Icons.draw_rounded;
      case PuzzleType.minesweeper:
        return Icons.flag_rounded;
    }
  }

  String _todayStatusLabel(ModeTodayStatus status) {
    if (status.totalToday <= 0) {
      return 'No new puzzles today';
    }
    if (status.completedToday >= status.totalToday) {
      return "Today's puzzles completed";
    }
    if (status.completedToday == 0) {
      return 'New puzzles today';
    }
    return "Today's puzzles: ${status.completedToday}/${status.totalToday}";
  }
}
