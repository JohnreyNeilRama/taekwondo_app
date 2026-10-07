import 'package:flutter/material.dart';

import '../services/attendance_storage.dart';
import '../theme/app_dark.dart';
import '../theme/app_theme.dart';

/// The ATTENDANCE section of a student's page: how many days they came, when
/// they were last scanned, and their recent check-ins, each with an undo for a
/// scan that was made by mistake.
///
/// It reads its own data, so the page around it can stay read-only.
class AttendanceHistoryCard extends StatefulWidget {
  const AttendanceHistoryCard({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  final int studentId;

  /// Only used to word the confirmation of an undo.
  final String studentName;

  @override
  State<AttendanceHistoryCard> createState() => _AttendanceHistoryCardState();
}

class _AttendanceHistoryCardState extends State<AttendanceHistoryCard> {
  /// How many check-ins are listed before "Show all".
  static const int _collapsedCount = 5;

  final AttendanceStorage _storage = AttendanceStorage();

  AttendanceHistory? _history;
  bool _failed = false;
  bool _showAll = false;

  /// True while an undo is being written, so a second tap cannot start another.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final history = await _storage.loadHistory(widget.studentId);
      if (!mounted) return;
      setState(() {
        _history = history;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  /// Asks first, then removes one check-in. The student can be scanned again
  /// for that day afterwards.
  Future<void> _undo(AttendanceRecord record) async {
    if (_busy) return;
    final name = widget.studentName.trim().isEmpty
        ? 'this student'
        : widget.studentName.trim();
    final label = _longDate(_parseDay(record.day) ?? record.checkedInAt);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Undo this scan?'),
        content: Text(
          'This removes the check-in of $name on $label at '
          '${_formatTime(record.checkedInAt)}. They can be scanned again '
          'afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove check-in'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final removed = await _storage.undoCheckIn(widget.studentId, record.id);
      await _load();
      _toast(
        removed ? 'Check-in removed' : 'That check-in was already removed',
      );
    } catch (_) {
      _toast('Could not remove the check-in. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppDark.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ATTENDANCE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.red,
            ),
          ),
          const SizedBox(height: 8),
          _body(),
        ],
      ),
    );
  }

  Widget _body() {
    final history = _history;
    if (history == null) {
      return Text(
        _failed ? 'Attendance could not be loaded.' : 'Loading attendance…',
        style: const TextStyle(fontSize: 13, color: AppColors.muted),
      );
    }

    final last = history.lastScanned;
    final records = history.records;
    final shown = _showAll || records.length <= _collapsedCount
        ? records
        : records.sublist(0, _collapsedCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Stat(
                label: 'Days attended',
                value: '${history.daysAttended}',
                valueSize: 20,
              ),
            ),
            Expanded(
              flex: 2,
              child: _Stat(
                label: 'Last scanned',
                value: last == null ? 'Never' : _lastLabel(last, DateTime.now()),
                valueSize: 14,
              ),
            ),
          ],
        ),
        const Divider(height: 24, color: AppColors.border),
        if (records.isEmpty)
          const Text(
            'No check-ins yet. They show up here once this student\'s QR '
            'code is scanned.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          )
        else ...[
          const Text(
            'Recent check-ins',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          for (final record in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _longDate(_parseDay(record.day) ?? record.checkedInAt),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black,
                          ),
                        ),
                        Text(
                          _formatTime(record.checkedInAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Undo this scan',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.undo,
                      size: 20,
                      color: AppColors.muted,
                    ),
                    onPressed: _busy ? null : () => _undo(record),
                  ),
                ],
              ),
            ),
          if (records.length > _collapsedCount)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _showAll = !_showAll),
                child: Text(
                  _showAll ? 'Show fewer' : 'Show all ${records.length}',
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// One headline number or phrase with its label above it.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.valueSize,
  });

  final String label;
  final String value;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: valueSize,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
      ],
    );
  }
}

const List<String> _weekdays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// The `yyyy-mm-dd` text of `attended_on` as a date, or null when it is not one.
DateTime? _parseDay(String day) => DateTime.tryParse(day);

/// "Tue, Oct 6, 2026".
String _longDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${_months[date.month - 1]} ${date.day}, '
    '${date.year}';

/// "9:30 AM".
String _formatTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final suffix = time.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}

/// "Today, 9:30 AM", "Yesterday, 6:05 PM", or the date and time further back.
String _lastLabel(DateTime when, DateTime now) {
  // Whole calendar days apart, counted on UTC midnights so a clock change
  // never makes a day 23 or 25 hours long.
  final days = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime.utc(when.year, when.month, when.day)).inDays;
  final time = _formatTime(when);
  if (days == 0) return 'Today, $time';
  if (days == 1) return 'Yesterday, $time';
  return '${_months[when.month - 1]} ${when.day}, ${when.year}, $time';
}
