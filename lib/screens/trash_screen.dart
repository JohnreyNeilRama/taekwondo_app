import 'package:flutter/material.dart';

import '../services/student_storage.dart';
import '../theme/app_dark.dart';
import '../widgets/app_page.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/student_avatar.dart';

/// The Trash: students who were deleted from TKD Records but can still be
/// brought back.
///
/// A student in the Trash keeps everything: the profile picture, the promotion
/// record and the achievements stay saved with them. **Restore** makes them
/// visible again, exactly as they were. **Delete Permanently** removes the
/// student and all of those records from the database, and asks first.
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final StudentStorage _storage = StudentStorage();

  List<TrashedStudent> _items = [];
  bool _loading = true;
  bool _failed = false;

  /// Ids of the students a restore or a permanent delete is running for, so a
  /// second tap cannot start the same action twice.
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _storage.loadTrash();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _removeFromList(int id) {
    setState(() => _items.removeWhere((item) => item.student.id == id));
  }

  /// Brings the student back to TKD Records with everything they had.
  Future<void> _restore(TrashedStudent item) async {
    final id = item.student.id;
    if (id == null || !_busy.add(id)) return;
    setState(() {});
    try {
      await _storage.restoreFromTrash(id);
      if (!mounted) return;
      _removeFromList(id);
      _toast('${item.student.name} restored to TKD Records');
    } catch (_) {
      // The Trash may have changed underneath (for example a restore from
      // another screen): read it again so the list shows what is really there.
      _toast('Could not restore ${item.student.name}. Please try again.');
      await _load();
    } finally {
      _busy.remove(id);
      if (mounted) setState(() {});
    }
  }

  /// Asks for confirmation, then removes the student and every record that
  /// belongs to them from the database.
  Future<void> _deletePermanently(TrashedStudent item) async {
    final id = item.student.id;
    if (id == null || _busy.contains(id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text(_permanentWarning(item)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppDark.crimson),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_busy.add(id)) return;
    setState(() {});
    try {
      await _storage.deletePermanently(id);
      if (!mounted) return;
      _removeFromList(id);
      // The students after this one moved up to close the gap, and that includes
      // the other students in the Trash, so their numbers have to be read again
      // instead of staying as the cards already show them.
      await _load();
      _toast('${item.student.name} deleted permanently');
    } catch (_) {
      _toast('Could not delete ${item.student.name}. Please try again.');
      await _load();
    } finally {
      _busy.remove(id);
      if (mounted) setState(() {});
    }
  }

  /// What the confirmation says will be lost, spelled out from what the student
  /// really has.
  static String _permanentWarning(TrashedStudent item) {
    final lost = <String>[
      if (item.student.photoBase64.isNotEmpty) 'profile picture',
      if (item.promotionCount > 0) 'promotion record',
      if (item.achievementCount > 0)
        item.achievementCount == 1
            ? '1 achievement record'
            : '${item.achievementCount} achievement records',
    ];
    final name = item.student.name;
    final buffer = StringBuffer('$name will be deleted permanently.');
    if (lost.isNotEmpty) {
      buffer.write(' Their ${_joinWithAnd(lost)} will be deleted too.');
    }
    buffer.write(' This cannot be undone.');
    return buffer.toString();
  }

  static String _joinWithAnd(List<String> parts) {
    if (parts.length == 1) return parts.first;
    return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  }

  @override
  Widget build(BuildContext context) {
    final count = _items.length;
    return AppPage(
      title: 'Trash',
      subtitle: '$count student${count == 1 ? '' : 's'}',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          const NoticeCard(
            icon: Icons.info_outline,
            message:
                'Deleted students are kept here with their profile '
                'picture, promotion record and achievements. Restore '
                'brings them back to TKD Records; Delete Permanently '
                'removes them for good.',
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_failed)
            const EmptyStateCard(
              icon: Icons.error_outline,
              title: 'Could not load the Trash',
              message: 'Please go back and try again.',
            )
          else if (_items.isEmpty)
            const EmptyStateCard(
              icon: Icons.delete_outline,
              title: 'Trash is empty',
              message:
                  'Students you delete are kept here, so they can be '
                  'restored if it was a mistake.',
            )
          else
            for (final item in _items)
              _TrashCard(
                item: item,
                busy: _busy.contains(item.student.id),
                onRestore: () => _restore(item),
                onDeletePermanently: () => _deletePermanently(item),
              ),
        ],
      ),
    );
  }
}

/// One student in the Trash, styled like the cards of the registry: picture,
/// name, nickname, registry number, when they were deleted, and the two
/// actions.
class _TrashCard extends StatelessWidget {
  const _TrashCard({
    required this.item,
    required this.busy,
    required this.onRestore,
    required this.onDeletePermanently,
  });

  final TrashedStudent item;
  final bool busy;
  final VoidCallback onRestore;
  final VoidCallback onDeletePermanently;

  /// `MM/DD/YYYY`, the date format used everywhere else in the app.
  static String _dateLabel(DateTime? moment) {
    if (moment == null) return '';
    final local = moment.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$month/$day/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final student = item.student;
    final deleted = _dateLabel(item.deletedAt);
    final kept = <String>[
      if (item.promotionCount > 0) 'Promotion record',
      if (item.achievementCount > 0)
        item.achievementCount == 1
            ? '1 achievement'
            : '${item.achievementCount} achievements',
    ];
    return DarkCard(
      margin: const EdgeInsets.only(bottom: 12),
      accent: AppDark.crimson,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudentAvatar(
                student: student,
                size: 56,
                borderRadius: 16,
                initialsFontSize: 17,
                backgroundColor: AppDark.surfaceHigh,
                initialsColor: AppDark.rose,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppDark.textPrimary,
                      ),
                    ),
                    if (student.nickname.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '"${student.nickname}"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppDark.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        AppChip(label: student.studentNo, emphasized: true),
                        if (deleted.isNotEmpty)
                          AppChip(label: 'Deleted $deleted'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (kept.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Kept with this student: ${kept.join(' \u00B7 ')}',
              style: const TextStyle(
                fontSize: 12,
                color: AppDark.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: busy ? null : onRestore,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Restore'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: OutlinedButton(
                  onPressed: busy ? null : onDeletePermanently,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: AppDark.rose,
                    side: BorderSide(
                      color: AppDark.crimson.withValues(alpha: 0.6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text(
                    'Delete Permanently',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
