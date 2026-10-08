import 'package:flutter/material.dart';

import '../services/appearance_settings.dart';
import '../services/backup_service.dart';
import '../services/class_schedule.dart';
import '../services/student_storage.dart';
import '../theme/app_dark.dart';
import '../widgets/app_page.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/registry_header.dart';
import 'appearance_screen.dart';
import 'class_days_screen.dart';
import 'data_transfer_screen.dart';
import 'trash_screen.dart';

/// Settings: the one place for everything that is not the day-to-day registry.
///
/// * **Trash** holds deleted students until they are restored or deleted for
///   good.
/// * **Data** backs the registry up, brings a backup in, and checks the saved
///   file.
/// * **Class days** sets the weekdays classes are held and marks cancelled
///   training.
/// * **Appearance** sets light or dark mode and how large the text is.
///
/// Each opens its own page. What a row says about its page (how many students
/// are in the Trash, whether a backup is due, the text size in use) is read
/// again whenever this page is shown and whenever one of those pages is closed.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.visits = 0, this.onReturn});

  /// Changes every time a destination is selected in the shell, so the rows
  /// read the Trash and the backup state again when the owner comes back.
  final int visits;

  /// Called after a page opened from here is closed, so the shell can refresh
  /// the backup dot on its bottom bar at once (exporting clears it).
  final VoidCallback? onReturn;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StudentStorage _students = StudentStorage();
  final BackupService _backup = BackupService();

  /// Students in the Trash, or null while unknown (or when it could not be
  /// read), in which case the row says nothing about a number.
  int? _trashCount;

  /// Whether a backup is due. Shown as a red "Backup due" tag on the Data row.
  bool _backupDue = false;

  /// The weekdays classes are held (Monday is 1), or null while unknown or when
  /// the owner never set them.
  Set<int>? _classDays;

  /// Whether today is marked training cancelled.
  bool _cancelledToday = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visits != widget.visits) _refresh();
  }

  /// Reads what the rows show. A row whose number cannot be read simply shows
  /// no number: problems with the database are reported where they happen (the
  /// pages themselves), never here.
  Future<void> _refresh() async {
    int? trash;
    var due = false;
    try {
      trash = (await _students.loadTrash()).length;
    } catch (_) {
      trash = null;
    }
    try {
      due = await _backup.reminderDue();
    } catch (_) {
      due = false;
    }
    Set<int>? days;
    var cancelledToday = false;
    try {
      final schedule = ClassSchedule();
      days = await schedule.load();
      cancelledToday = ClassSchedule.isCancelled(
        await schedule.loadCancelled(),
        DateTime.now(),
      );
    } catch (_) {
      days = null;
    }
    if (!mounted) return;
    setState(() {
      _trashCount = trash;
      _backupDue = due;
      _classDays = days;
      _cancelledToday = cancelledToday;
    });
  }

  /// Opens [page] on top of this one and reads the rows again when it closes.
  Future<void> _open(Widget page) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => page),
    );
    if (!mounted) return;
    await _refresh();
    widget.onReturn?.call();
  }

  String get _trashSubtitle {
    final count = _trashCount;
    if (count == null) return 'Restore or permanently delete students';
    if (count == 0) return 'No deleted students';
    return '$count deleted student${count == 1 ? '' : 's'}';
  }

  static const List<String> _dayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// The class weekdays in short form ("Mon \u00B7 Wed \u00B7 Fri"), with a note
  /// when today's training is cancelled.
  String get _classDaysSubtitle {
    final days = _classDays;
    final base = days == null
        ? 'Not set yet'
        : days.isEmpty
        ? 'No class days'
        : [
            for (final day in (days.toList()..sort())) _dayNames[day - 1],
          ].join(' \u00B7 ');
    return _cancelledToday ? '$base \u00B7 Cancelled today' : base;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const RegistryHeader(),
        Expanded(
          child: AppSheet(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                const PageIntro(
                  title: 'Settings',
                  subtitle: 'Records, backup and display',
                ),
                const SizedBox(height: 28),
                const SectionLabel('RECORDS'),
                const SizedBox(height: 10),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.delete_outline,
                      title: 'Trash',
                      subtitle: _trashSubtitle,
                      tag: (_trashCount ?? 0) > 0
                          ? AppChip(label: '$_trashCount', emphasized: true)
                          : null,
                      onTap: () => _open(const TrashScreen()),
                    ),
                    _SettingsRow(
                      icon: Icons.swap_horiz_outlined,
                      title: 'Data',
                      subtitle: 'Back up, import and check your records',
                      tag: _backupDue
                          ? const _DueTag(label: 'Backup due')
                          : null,
                      onTap: () => _open(const DataTransferScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const SectionLabel('ATTENDANCE'),
                const SizedBox(height: 10),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.calendar_view_week,
                      title: 'Class days',
                      subtitle: _classDaysSubtitle,
                      onTap: () => _open(const ClassDaysScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const SectionLabel('PREFERENCES'),
                const SizedBox(height: 10),
                ValueListenableBuilder<AppTextSize>(
                  valueListenable: AppearanceSettings.textSize,
                  builder: (context, size, _) => _SettingsGroup(
                    children: [
                      _SettingsRow(
                        icon: Icons.palette_outlined,
                        title: 'Appearance',
                        subtitle:
                            '${AppearanceSettings.lightMode.value ? 'Light' : 'Dark'}'
                            ' mode \u00B7 ${size.label} text',
                        onTap: () => _open(const AppearanceScreen()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One card holding the rows of a group, with a hairline between them.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppDark.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDark.border),
        boxShadow: AppDark.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            // The line starts under the text, not under the icon, the way a
            // grouped list does.
            if (i > 0) const Divider(height: 1, indent: 74, endIndent: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A row of Settings: an icon plate, the name of the page and one line about
/// it, an optional tag (a count, a warning) and a chevron. The whole row is the
/// button, and it is always at least 68 high.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tag,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? tag;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        splashColor: AppDark.crimson.withValues(alpha: 0.12),
        highlightColor: AppDark.crimson.withValues(alpha: 0.06),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconPlate(icon: icon, size: 46),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppDark.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: AppDark.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (tag != null) ...[const SizedBox(width: 8), tag!],
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 24,
                  color: AppDark.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The small red tag that says something on this page needs attention.
class _DueTag extends StatelessWidget {
  const _DueTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppDark.crimson.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppDark.crimson.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppDark.crimson,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppDark.rose,
            ),
          ),
        ],
      ),
    );
  }
}
