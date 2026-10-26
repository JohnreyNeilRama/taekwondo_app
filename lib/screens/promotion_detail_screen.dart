import 'package:flutter/material.dart';

import '../models/belt.dart';
import '../models/promotion_record.dart';
import '../services/promotion_storage.dart';
import '../theme/app_dark.dart';
import '../widgets/app_page.dart';
import '../widgets/empty_state_card.dart';

/// Read-only view of one student's promotion record: name, current belt and
/// last promotion date, then every belt they held before it — one card per
/// belt — with Back and Edit actions.
class PromotionDetailScreen extends StatefulWidget {
  const PromotionDetailScreen({super.key, required this.record});

  final PromotionRecord record;

  @override
  State<PromotionDetailScreen> createState() => _PromotionDetailScreenState();
}

class _PromotionDetailScreenState extends State<PromotionDetailScreen> {
  final PromotionStorage _storage = PromotionStorage();

  /// The student's earlier belts, the most recent first; null while loading.
  List<PromotionHistoryEntry>? _history;
  bool _failed = false;

  PromotionRecord get record => widget.record;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _storage.loadHistory(record.studentId);
      if (!mounted) return;
      setState(() => _history = history);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Promotion Details',
      subtitle: record.studentName,
      bottom: _editBar(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          _beltCard(),
          const SizedBox(height: 16),
          _detailsCard(),
          const SizedBox(height: 24),
          SectionLabel(
            'PROMOTION HISTORY',
            trailing: _history == null || _history!.isEmpty
                ? null
                : Text(
                    '${_history!.length} previous '
                    'belt${_history!.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppDark.textSecondary,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          ..._historySection(),
        ],
      ),
    );
  }

  /// The hero of the page: the current belt, large, on a crimson-washed card,
  /// with the date the student was promoted to it.
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
                if (record.lastPromotionDate.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  AppChip(
                    icon: Icons.event_outlined,
                    label: 'Promoted ${record.lastPromotionDate}',
                  ),
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

  /// One card per earlier belt, the most recent first — never merged into a
  /// single card — or a note when there is nothing to show yet.
  List<Widget> _historySection() {
    if (_failed) {
      return const [
        NoticeCard(
          icon: Icons.error_outline,
          message: 'Could not load the promotion history from this device.',
        ),
      ];
    }
    final history = _history;
    if (history == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (history.isEmpty) {
      return const [
        NoticeCard(
          icon: Icons.history,
          message:
              'No earlier belts yet. When this student is promoted, their '
              'current belt and its date are kept here.',
        ),
      ];
    }
    return [for (final entry in history) _HistoryCard(entry: entry)];
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

/// One earlier belt: a swatch in the belt's colour, the belt, and the date the
/// student was promoted to it, with the belt colour down the left edge.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final PromotionHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final family = BeltCatalog.familyOf(entry.belt);
    final color = family == null ? null : _visibleOnDark(Color(family.colorValue));
    return DarkCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      accent: color ?? AppDark.textSecondary,
      child: Row(
        children: [
          IconPlate(
            icon: Icons.military_tech_outlined,
            color: color ?? AppDark.textSecondary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Previous Belt',
                  style: TextStyle(fontSize: 12, color: AppDark.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.belt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppDark.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                AppChip(
                  icon: Icons.event_outlined,
                  label: entry.promotionDate.isEmpty
                      ? 'Date not recorded'
                      : 'Promoted ${entry.promotionDate}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A belt colour made visible on the dark page: a black belt would vanish into
/// the navy, so very dark colours are lifted to a light gray.
Color _visibleOnDark(Color color) =>
    color.computeLuminance() < 0.08 ? const Color(0xFF8FA0BA) : color;
