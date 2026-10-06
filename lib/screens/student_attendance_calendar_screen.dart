import 'package:flutter/material.dart';

import '../models/student.dart';
import '../services/attendance_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/student_avatar.dart';

const Color _presentGreen = Color(0xFF16A34A);

/// One student's attendance on a monthly calendar.
///
/// Present days are green and absent days are red, with the month's totals
/// below. Use the arrows (or swipe the calendar) to go back through the
/// student's history; there is nothing to see in a future month, so the
/// forward arrow stops at the current one.
///
/// "Absent" means a scheduled class day and this student was not checked in,
/// counted from the day they were enrolled up to yesterday.
class StudentAttendanceCalendarScreen extends StatefulWidget {
  const StudentAttendanceCalendarScreen({
    super.key,
    required this.student,
    this.initialMonth,
  });

  final Student student;

  /// The month to open on. The current month when left out.
  final DateTime? initialMonth;

  @override
  State<StudentAttendanceCalendarScreen> createState() =>
      _StudentAttendanceCalendarScreenState();
}

class _StudentAttendanceCalendarScreenState
    extends State<StudentAttendanceCalendarScreen> {
  final AttendanceStorage _storage = AttendanceStorage();

  /// The first day of the month on screen.
  late DateTime _month;
  StudentMonthAttendance? _data;
  bool _failed = false;
  bool _busy = false;

  /// Counts loads so a slow answer for a month the owner already left can
  /// never overwrite the month now on screen.
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    final start = widget.initialMonth ?? DateTime.now();
    _month = DateTime(start.year, start.month);
    _load();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _load() async {
    final studentId = widget.student.id;
    if (studentId == null) {
      setState(() => _failed = true);
      return;
    }
    final id = ++_loadId;
    try {
      final data = await _storage.loadMonth(studentId, _month);
      if (!mounted || id != _loadId) return;
      setState(() {
        _data = data;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || id != _loadId) return;
      setState(() => _failed = true);
    }
  }

  void _changeMonth(int delta) {
    if (delta > 0 && _isCurrentMonth) return;
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _data = null;
      _failed = false;
    });
    _load();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  /// Shows the check-in on [day], or records / removes one.
  Future<void> _onDayTap(int day) async {
    if (_busy) return;
    final student = widget.student;
    final id = student.id;
    if (id == null) return;

    final date = DateTime(_month.year, _month.month, day);
    final label = _longDate(date);
    final name = student.name.trim().isEmpty
        ? 'this student'
        : student.name.trim();
    final record = _data?.presentByDay[day];

    if (record != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Check-in'),
          content: Text(
            '$name was checked in on $label at '
            '${_formatTime(record.checkedInAt)}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Close'),
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
        final removed = await _storage.undoCheckIn(id, record.id);
        await _load();
        _toast(
          removed ? 'Check-in removed' : 'That check-in was already removed',
        );
      } catch (_) {
        _toast('Could not remove the check-in. Please try again.');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark present?'),
        content: Text('Record a check-in for $name on $label?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Mark present'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final moment = date == _today
          ? now
          : DateTime(
              date.year,
              date.month,
              date.day,
              now.hour,
              now.minute,
              now.second,
            );
      await _storage.checkIn(student, now: moment);
      await _load();
      _toast('Marked present');
    } catch (_) {
      _toast('Could not record the check-in. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _calendarCard(),
                const SizedBox(height: 16),
                _summary(),
                const SizedBox(height: 12),
                Text(
                  _data?.scheduleSet == false
                      ? 'Set the class days from Attendance so missed classes '
                          'can be shown. They are not guessed from who was '
                          'scanned. Tap a day to add or remove a check-in.'
                      : 'Tap a day to see the check-in time, or to add or '
                          'remove attendance. Absent means a scheduled class '
                          'day this student missed, counted from the day they '
                          'were enrolled. Today is not counted as absent until '
                          'the day ends.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final student = widget.student;
    return Container(
      color: AppColors.black,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              StudentAvatar(
                student: student,
                size: 40,
                shape: BoxShape.circle,
                backgroundColor: AppColors.red,
                initialsColor: Colors.white,
                initialsFontSize: 13,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name.isEmpty ? 'Unnamed student' : student.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Attendance calendar',
                      style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
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

  Widget _calendarCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: GestureDetector(
        // Swipe left for the next month, right for the previous one.
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -300) _changeMonth(1);
          if (velocity > 300) _changeMonth(-1);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            _monthBar(),
            const SizedBox(height: 4),
            _weekdayRow(),
            const SizedBox(height: 6),
            if (_failed) _errorBox() else _grid(),
            const SizedBox(height: 12),
            if (_data == null && !_failed)
              const LinearProgressIndicator(minHeight: 2)
            else
              const SizedBox(height: 2),
            const SizedBox(height: 12),
            _legend(),
          ],
        ),
      ),
    );
  }

  Widget _monthBar() {
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous month',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _changeMonth(-1),
        ),
        Expanded(
          child: Text(
            '${_monthNames[_month.month - 1]} ${_month.year}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          icon: const Icon(Icons.chevron_right),
          onPressed: _isCurrentMonth ? null : () => _changeMonth(1),
        ),
      ],
    );
  }

  Widget _weekdayRow() {
    return Row(
      children: [
        for (final label in _weekdayLabels)
          Expanded(
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _errorBox() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Text(
            'Could not load the attendance for this month.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _load, child: const Text('Try again')),
        ],
      ),
    );
  }

  /// The month as a grid of day cells, Sunday first. The cells before the 1st
  /// are blank so the days land under the right weekday.
  Widget _grid() {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // DateTime.weekday is 1 (Monday) to 7 (Sunday); Sunday-first wants 0 to 6.
    final blanks = DateTime(_month.year, _month.month, 1).weekday % 7;
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: [
        for (var i = 0; i < blanks; i++) const SizedBox.shrink(),
        for (var day = 1; day <= daysInMonth; day++) _dayCell(day),
      ],
    );
  }

  Widget _dayCell(int day) {
    final today = _today;
    final date = DateTime(_month.year, _month.month, day);
    final isToday = date == today;
    final isFuture = date.isAfter(today);
    final present = _data?.presentDays.contains(day) ?? false;
    final absent = _data?.absentDays.contains(day) ?? false;

    final Color? fill = present
        ? _presentGreen
        : absent
        ? AppColors.red
        : null;
    final status = present
        ? 'present'
        : absent
        ? 'absent'
        : 'no record';

    return Semantics(
      button: !isFuture,
      enabled: !isFuture,
      label: '${_monthNames[_month.month - 1]} $day, $status',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isFuture || _busy ? null : () => _onDayTap(day),
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(10),
              border: isToday && fill == null
                  ? Border.all(color: AppColors.black, width: 1.5)
                  : null,
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: fill != null || isToday
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: fill != null
                      ? Colors.white
                      : isFuture
                      ? AppColors.muted
                      : AppColors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _legend() {
    Widget item(Color? color, String label, {bool outlined = false}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: outlined
                  ? Border.all(color: AppColors.black, width: 1.5)
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 6,
      children: [
        item(_presentGreen, 'Present'),
        item(AppColors.red, 'Absent'),
        item(null, 'Today', outlined: true),
      ],
    );
  }

  Widget _summary() {
    final data = _data;
    Widget box(String label, String value, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        box(
          'Present days',
          data == null ? '-' : '${data.presentDays.length}',
          _presentGreen,
        ),
        const SizedBox(width: 12),
        box(
          'Absent days',
          data == null ? '-' : '${data.absentDays.length}',
          AppColors.red,
        ),
      ],
    );
  }
}

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> _weekdayLabels = [
  'Su',
  'Mo',
  'Tu',
  'We',
  'Th',
  'Fr',
  'Sa',
];

const List<String> _weekdaysLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String _longDate(DateTime day) =>
    '${_weekdaysLong[day.weekday - 1]}, ${_monthNames[day.month - 1]} '
    '${day.day}, ${day.year}';

String _formatTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final suffix = time.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}
