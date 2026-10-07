import 'package:flutter/material.dart';

import '../models/promotion_record.dart';
import '../theme/app_dark.dart';
import '../widgets/app_page.dart';
import '../widgets/empty_state_card.dart';

/// Read-only view of one student's promotion record: name, current belt and
/// last promotion date, with Back and Edit actions.
class PromotionDetailScreen extends StatelessWidget {
  const PromotionDetailScreen({super.key, required this.record});

  final PromotionRecord record;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Promotion Details',
      subtitle: record.studentName,
      bottom: _editBar(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [_beltCard(), const SizedBox(height: 16), _detailsCard()],
      ),
    );
  }

  /// The hero of the page: the current belt, large, on a crimson-washed card,
  /// with the student's registry number beside it.
  Widget _beltCard() {
    final belt = record.belt.isEmpty ? 'Not set' : record.belt;
    return DarkCard(
      accent: AppDark.crimson,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const IconPlate(
            icon: Icons.emoji_events,
            size: 54,
            color: AppDark.crimson,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Belt',
                  style: TextStyle(fontSize: 12, color: AppDark.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  belt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: AppDark.textPrimary,
                  ),
                ),
                if (record.studentNo.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  AppChip(label: record.studentNo, emphasized: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsCard() {
    return SectionCard(
      icon: Icons.event_outlined,
      title: 'Promotion',
      subtitle: 'Record information',
      showDivider: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
        child: Column(
          children: [
            _row('Student Name', record.studentName),
            const SizedBox(height: 14),
            _row('Current Belt', record.belt.isEmpty ? 'Not set' : record.belt),
            const SizedBox(height: 14),
            _row(
              'Last Promotion Date',
              record.lastPromotionDate.isEmpty
                  ? 'Not set'
                  : record.lastPromotionDate,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppDark.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppDark.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _editBar(BuildContext context) {
    return AppActionBar(
      child: CrimsonButton(
        label: 'Edit',
        icon: Icons.edit_outlined,
        expand: true,
        onPressed: () => Navigator.of(context).pop(record),
      ),
    );
  }
}
