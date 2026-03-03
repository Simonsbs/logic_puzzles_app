import 'package:flutter/material.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';

class PuzzleTypeCard extends StatelessWidget {
  const PuzzleTypeCard({
    super.key,
    required this.type,
    required this.onTap,
  });

  final PuzzleType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final available = type.isAvailableNow;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(type.displayName, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                available ? 'Playable now' : 'Coming soon',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: available ? Colors.green.shade700 : Colors.orange.shade800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
