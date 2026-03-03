import 'package:flutter/material.dart';
import 'package:logic_puzzles_app/core/models/mode_streak.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';

class PuzzleTypeCard extends StatelessWidget {
  const PuzzleTypeCard({
    super.key,
    required this.type,
    required this.onTap,
    this.streak,
  });

  final PuzzleType type;
  final VoidCallback onTap;
  final ModeStreak? streak;

  @override
  Widget build(BuildContext context) {
    final available = type.isAvailableNow;
    final accent =
        available ? const Color(0xFF0D8A63) : const Color(0xFFCC8A17);

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
                  child: Icon(
                    available ? Icons.extension : Icons.hourglass_bottom,
                    color: accent,
                  ),
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
                        available ? 'Playable now' : 'Coming soon',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (available && streak != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          'Streak B:${streak!.basicDays}  P:${streak!.proDays}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF3D5A4F),
                            fontWeight: FontWeight.w700,
                          ),
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
}
