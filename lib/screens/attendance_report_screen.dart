import 'package:flutter/material.dart';

import '../models/student.dart';
import '../services/attendance_storage.dart';
import '../services/class_schedule.dart';
import '../theme/app_theme.dart';
import '../widgets/student_avatar.dart';
import 'class_days_screen.dart';

/// The attendance report: pick a day and see who was present and who was
/// absent.
///
/// Present students come from the check-ins saved for that day. Absent students
/// are every student in the registry (the Trash is left out) who has no
/// check-in on a scheduled class day and had already been enrolled by then; a
/// student who joined after that day is in neither list. Whether a class was
/// held is the owner's weekday schedule, not a guess from who was scanned.
class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key, this.initialDay});

  /// The day to open on. Today when left out.
  final DateTime? initialDay;

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  final AttendanceStorage _storage = AttendanceStorage();

  late DateTime _day;
  AttendanceReport? _report;
  bool _failed = false;

  /// Counts loads so a slow answer for a day the owner already left can never
  /// overwrite the answer for the day now on screen.
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    final start = widget.initialDay ?? DateTime.now();
    _day = DateTime(start.year, start.month, start.day);
    _load();
  }

  bool get _isToday => _sameDay(_day, DateTime.now());

  Future<void> _load() async {
    final id = ++_loadId;
    try {
      final report = await _storage.loadReport(_day);
      if (!mounted || id != _loadId) return;
      setState(() {
        _report = report;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || id != _loadId) return;
      setState(() => _failed = true);
    }
  }

  void _setDay(DateTime day) {
    setState(() {
      _day = DateTime(day.year, day.month, day.day);
      _report = null;
      _failed = false;
    });
    _load();
  }

  Future<void> _openClassDays() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ClassDaysScreen()),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _toggleCancelled() async {
    final cancelled = _report?.trainingCancelled ?? false;
    try {
      await ClassSchedule().setCancelled(_day, !cancelled);
      if (!mounted) return;
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Could not update the cancelled day. Please try again.',
            ),
          ),
        );
    }
  }

  Future<void> _pickDay() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: 'Select a day',
    );
    if (picked == null || !mounted) return;
    _setDay(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          _dayBar(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
              const SizedBox(width: 4),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance report',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Who was present and who was absent',
                      style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _report?.trainingCancelled == true
                    ? 'Remove training cancelled'
                    : 'Training cancelled',
                icon: Icon(
                  _report?.trainingCancelled == true
                      ? Icons.event_busy
                      : Icons.event_busy_outlined,
                  color: _report?.trainingCancelled == true
                      ? AppColors.cancelled
                      : Colors.white,
                ),
                onPressed: _report == null ? null : _toggleCancelled,
              ),
              IconButton(
                tooltip: 'Class days',
                icon: const Icon(Icons.calendar_view_week, color: Colors.white),
                onPressed: _openClassDays,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous day',
            icon: const Icon(Icons.chevron_left),
            onPressed: () =>
                _setDay(DateTime(_day.year, _day.month, _day.day - 1)),
          ),
          Expanded(
            child: InkWell(
              onTap: _pickDay,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: AppColors.red,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _longDate(_day),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.black,
                        ),
                      ),
                    ),
                    if (_isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.redTint,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.red,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next day',
            icon: const Icon(Icons.chevron_right),
            onPressed: _isToday
                ? null
                : () => _setDay(DateTime(_day.year, _day.month, _day.day + 1)),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not load the attendance for this day.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    final report = _report;
    if (report == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final heldClass = report.sessionHeld;
    final cancelled = report.trainingCancelled;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          _summary(report),
          Material(
            color: AppColors.surface,
            child: TabBar(
              labelColor: AppColors.black,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.red,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              tabs: [
                Tab(
                  text: cancelled
                      ? 'Present (-)'
                      : 'Present (${report.present.length})',
                ),
                Tab(
                  text: cancelled
                      ? 'Absent (-)'
                      : 'Absent (${heldClass ? report.absent.length : '-'})',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: TabBarView(
              children: [_presentList(report), _absentList(report)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(AttendanceReport report) {
    final cancelled = report.trainingCancelled;
    final heldClass = report.sessionHeld;
    final rate = heldClass && report.total > 0
        ? '${(report.present.length * 100 / report.total).round()}%'
        : '-';
    Widget box(String label, String value, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
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
                  fontSize: 22,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          box(
            'Present',
            cancelled ? '-' : '${report.present.length}',
            const Color(0xFF15803D),
          ),
          const SizedBox(width: 8),
          box(
            'Absent',
            heldClass ? '${report.absent.length}' : '-',
            AppColors.red,
          ),
          const SizedBox(width: 8),
          box('Attendance', rate, AppColors.black),
        ],
      ),
    );
  }

  Widget _presentList(AttendanceReport report) {
    if (report.trainingCancelled) {
      return _cancelledMessage();
    }
    if (report.present.isEmpty) {
      return _message(
        report.total == 0
            ? 'There are no students in the registry yet.'
            : 'No one was checked in on this day.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: report.present.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = report.present[index];
        return _StudentTile(
          student: entry.student,
          trailing: _formatTime(entry.checkedInAt),
          trailingColor: const Color(0xFF15803D),
        );
      },
    );
  }

  Widget _absentList(AttendanceReport report) {
    if (report.trainingCancelled) {
      return _cancelledMessage();
    }
    if (!report.scheduleSet) {
      return _message(
        'Set the weekdays classes run so absences can be counted. '
        'They are not guessed from who was scanned.',
        action: 'Set class days',
        onAction: _openClassDays,
      );
    }
    if (!report.sessionHeld) {
      return _message(
        'This is not a class day on the schedule, so there is no absent list. '
        'A make-up class can still be checked in and will show under Present.',
        action: 'Edit class days',
        onAction: _openClassDays,
      );
    }
    if (report.absent.isEmpty) {
      return _message('Everyone was present.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: report.absent.length + (_isToday ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == report.absent.length) {
          return const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Absent lists every student who was already enrolled on this '
              'day and was not checked in. Students who joined later are '
              'left out.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          );
        }
        return _StudentTile(
          student: report.absent[index],
          trailing: 'Absent',
          trailingColor: AppColors.red,
        );
      },
    );
  }

  Widget _cancelledMessage() {
    return _message(
      'Training was cancelled on this day. It is not counted as present or '
      'absent, even if it is a regular class weekday.',
      action: 'Remove cancellation',
      onAction: _toggleCancelled,
    );
  }

  Widget _message(
    String text, {
    String? action,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            if (action != null && onAction != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onAction, child: Text(action)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({
    required this.student,
    required this.trailing,
    required this.trailingColor,
  });

  final Student student;
  final String trailing;
  final Color trailingColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          StudentAvatar(
            student: student,
            size: 40,
            borderRadius: 10,
            initialsFontSize: 14,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
                if (student.studentNo.isNotEmpty)
                  Text(
                    student.studentNo,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            trailing,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: trailingColor,
            ),
          ),
        ],
      ),
    );
  }
}

const List<String> _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
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

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _longDate(DateTime day) =>
    '${_weekdays[day.weekday - 1]}, ${_months[day.month - 1]} ${day.day}, '
    '${day.year}';

String _formatTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final suffix = time.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}
