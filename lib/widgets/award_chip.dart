import 'package:flutter/material.dart';

import '../models/achievement_record.dart';

/// Medal chip for one award, washed with the medal colour so Gold, Silver and
/// Bronze stay readable at a glance on the dark cards.
class AwardChip extends StatelessWidget {
  const AwardChip({super.key, required this.award, this.count});

  final Award award;

  /// When set, the chip reads `Gold ×2` instead of just `Gold`, which lets a
  /// student card summarise several wins without growing taller.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final color = Color(award.colorValue);
    final label = count == null ? award.label : '${award.label} ×$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
