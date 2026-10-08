import 'package:flutter/material.dart';

import '../models/achievement_record.dart';
import '../models/student.dart';
import '../services/achievement_storage.dart';
import '../theme/app_dark.dart';
import '../widgets/app_page.dart';
import '../widgets/award_chip.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/student_avatar.dart';
import 'achievement_form_dialog.dart';

/// One student achievement records.
///
/// The screen only edits this student slice: every add, edit and delete is
/// saved through [AchievementStorage] as its own row, then [onChanged] tells
/// the Achievement list — which owns the full set of records — to read the
/// saved rows again.
class AchievementDetailScreen extends StatefulWidget {
  const AchievementDetailScreen({
    super.key,
    required this.student,
    required this.records,
    required this.onChanged,
  });

  final Student student;

  /// Only this student achievements, as loaded by the list screen.
  final List<AchievementRecord> records;

  /// Called after every add, edit or delete so the list screen can re-read the
  /// records it shows.
  final Future<void> Function() onChanged;

  @override
  State<AchievementDetailScreen> createState() =>
      _AchievementDetailScreenState();
}

class _AchievementDetailScreenState extends State<AchievementDetailScreen> {
  final AchievementStorage _storage = AchievementStorage();

  late List<AchievementRecord> _records = _newestFirst(widget.records);

  /// Newest award first: the most recent win is the one a coach looks for.
  static List<AchievementRecord> _newestFirst(List<AchievementRecord> records) {
    final sorted = List<AchievementRecord>.from(records);
    sorted.sort((a, b) => _sortKey(b).compareTo(_sortKey(a)));
    return sorted;
  }

  /// Sort key for the stored `MM/DD/YYYY` text; undated records sort last.
  static String _sortKey(AchievementRecord record) {
    final parts = record.date.split('/');
    if (parts.length != 3) return '';
    final month = parts[0].padLeft(2, '0');
    final day = parts[1].padLeft(2, '0');
    return '${parts[2]}-$month-$day';
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  /// Records a new award for this student (the form is locked to them) and
  /// shows the row the database inserted.
  Future<void> _add() async {
    final saved = await AchievementFormDialog.show(
      context,
      student: widget.student,
    );
    if (saved == null || !mounted) return;
    final AchievementRecord inserted;
    try {
      inserted = await _storage.insert(saved);
    } catch (_) {
      _toast('Could not save the achievement. Please try again.');
      return;
    }
    if (!mounted) return;
    setState(() => _records = _newestFirst([..._records, inserted]));
    await widget.onChanged();
  }

  /// Writes the edited award back onto the row it already has, so the other
  /// awards of this student are left untouched.
  Future<void> _edit(AchievementRecord record) async {
    final saved = await AchievementFormDialog.show(
      context,
      student: widget.student,
      initial: record,
    );
    if (saved == null || !mounted) return;
    try {
      await _storage.update(saved);
    } catch (_) {
      _toast('Could not save the achievement. Please try again.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _records = _newestFirst([
        for (final existing in _records)
          if (existing.id == saved.id) saved else existing,
      ]);
    });
    await widget.onChanged();
  }

  Future<void> _confirmDelete(AchievementRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete achievement?'),
        content: Text(
          'The award from ${record.event} will be removed from '
          '${widget.student.name} permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppDark.crimson),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final id = record.id;
    // A record without an id was never inserted, so there is nothing to remove.
    if (id == null) return;
    try {
      await _storage.delete(id);
    } catch (_) {
      _toast('Could not delete the achievement. Please try again.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _records = [
        for (final existing in _records)
          if (existing.id != id) existing,
      ];
    });
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Achievement Details',
      subtitle: widget.student.name,
      bottom: _actionBar(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          _studentCard(),
          const SizedBox(height: 4),
          _recordsHeading(),
          const SizedBox(height: 14),
          if (_records.isEmpty)
            EmptyStateCard(
              icon: Icons.workspace_premium_outlined,
              title: 'No achievements yet',
              message:
                  'Record ${widget.student.name} first award: pick the '
                  'date, the event and the medal.',
            )
          else
            for (final record in _records)
              _RecordTile(
                record: record,
                onEdit: () => _edit(record),
                onDelete: () => _confirmDelete(record),
              ),
        ],
      ),
    );
  }

  /// The student the awards belong to: picture, name, nickname and TKD number.
  Widget _studentCard() {
    final nickname = widget.student.nickname;
    return DarkCard(
      margin: const EdgeInsets.only(bottom: 16),
      accent: AppDark.crimson,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          StudentAvatar(
            student: widget.student,
            size: 60,
            borderRadius: 18,
            initialsFontSize: 20,
            backgroundColor: AppDark.surfaceHigh,
            initialsColor: AppDark.textSecondary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: AppDark.textPrimary,
                  ),
                ),
                if (nickname.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '"$nickname"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: AppDark.rose,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordsHeading() {
    final total = _records.length;
    return SectionLabel(
      'ACHIEVEMENT RECORDS',
      trailing: Text(
        '$total record${total == 1 ? '' : 's'}',
        style: const TextStyle(fontSize: 12, color: AppDark.textSecondary),
      ),
    );
  }

  Widget _actionBar() {
    return AppActionBar(
      child: CrimsonButton(
        label: 'Add Achievement',
        icon: Icons.add,
        expand: true,
        onPressed: _add,
      ),
    );
  }
}

/// One achievement record: event, date and medal, with edit and delete.
class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  final AchievementRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final medal = record.medal;
    final medalColor = medal == null ? null : Color(medal.colorValue);
    return DarkCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      accent: medalColor ?? AppDark.border,
      onTap: onEdit,
      child: Row(
        children: [
          IconPlate(
            icon: Icons.emoji_events,
            size: 48,
            color: medalColor == null
                ? AppDark.textSecondary
                : AppDark.readable(medalColor),
            background: medal == null
                ? AppDark.surfaceHigh
                : medalColor!.withValues(alpha: 0.16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.event.isEmpty ? 'Achievement' : record.event,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppDark.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  record.date.isEmpty ? 'No date recorded' : record.date,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppDark.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                medal == null
                    ? const AppChip(label: 'No award set')
                    : AwardChip(award: medal),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: AppDark.crimson),
          ),
        ],
      ),
    );
  }
}
