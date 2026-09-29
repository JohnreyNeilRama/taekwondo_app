import 'package:flutter/material.dart';

import '../models/achievement_record.dart';
import '../models/student.dart';
import '../services/achievement_storage.dart';
import '../theme/app_theme.dart';
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
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _studentCard(),
                const SizedBox(height: 8),
                _recordsHeading(),
                const SizedBox(height: 12),
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
          ),
          _actionBar(),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      color: AppColors.black,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Achievement Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      widget.student.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFD1D5DB),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The student the awards belong to: picture, name, nickname and TKD number.
  Widget _studentCard() {
    final nickname = widget.student.nickname;
    return SectionCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            StudentAvatar(
              student: widget.student,
              size: 46,
              borderRadius: 12,
              initialsFontSize: 16,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.student.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                  if (nickname.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '"$nickname"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  AppChip(label: widget.student.studentNo, emphasized: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordsHeading() {
    final total = _records.length;
    return Row(
      children: [
        const Expanded(
          child: Text(
            'ACHIEVEMENT RECORDS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.muted,
            ),
          ),
        ),
        Text(
          '$total record${total == 1 ? '' : 's'}',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    );
  }

  Widget _actionBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Achievement'),
            ),
          ),
        ),
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
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: medal == null
                    ? AppColors.iconCircle
                    : Color(medal.tintValue),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.emoji_events,
                size: 20,
                color: medal == null
                    ? AppColors.muted
                    : Color(medal.colorValue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.event.isEmpty ? 'Achievement' : record.event,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    record.date.isEmpty ? 'No date recorded' : record.date,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  medal == null
                      ? AppChip(label: 'No award set')
                      : AwardChip(award: medal),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: AppColors.red),
            ),
          ],
        ),
      ),
    );
  }
}
