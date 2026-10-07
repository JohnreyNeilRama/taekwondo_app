import 'package:flutter/material.dart';

import '../services/class_schedule.dart';
import '../theme/app_dark.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page.dart';

/// Lets the owner mark the weekdays classes run on, such as Monday, Wednesday
/// and Friday.
///
/// Pops with `true` once saved, so the screen that opened it can re-read the
/// schedule.
class ClassDaysScreen extends StatefulWidget {
  const ClassDaysScreen({super.key});

  @override
  State<ClassDaysScreen> createState() => _ClassDaysScreenState();
}

class _ClassDaysScreenState extends State<ClassDaysScreen> {
  static const List<String> _short = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const List<String> _long = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final ClassSchedule _schedule = ClassSchedule();

  Set<int> _days = {};
  Set<String> _cancelled = {};
  late DateTime _month;
  bool _loaded = false;
  bool _saving = false;
  bool _cancelledChanged = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    Set<int>? saved;
    Set<String> cancelled = {};
    try {
      saved = await _schedule.load();
      cancelled = await _schedule.loadCancelled();
    } catch (_) {
      // The page still opens, empty: the owner can set the days again.
    }
    if (!mounted) return;
    setState(() {
      _days = {...?saved};
      _cancelled = cancelled;
      _loaded = true;
    });
  }

  void _toggle(int weekday, bool selected) {
    setState(() {
      if (selected) {
        _days.add(weekday);
      } else {
        _days.remove(weekday);
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _schedule.save(_days);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not save the class days. Please try again.'),
          ),
        );
    }
  }

  /// "Monday", "Monday and Friday", "Monday, Wednesday and Friday".
  String _describe() {
    if (_days.isEmpty) return 'No class days selected.';
    final names = [
      for (var weekday = ClassSchedule.monday;
          weekday <= ClassSchedule.sunday;
          weekday++)
        if (_days.contains(weekday)) _long[weekday - 1],
    ];
    final list = names.length == 1
        ? names.single
        : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    return 'Classes run on $list.';
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Class days',
      subtitle: 'Weekdays and cancelled training',
      onBack: () => Navigator.of(context).pop(_cancelledChanged),
      bottom: _buildSaveBar(),
      child: _loaded
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                _card(),
                const SizedBox(height: 16),
                _cancelledCard(),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _card() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppDark.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDark.border),
        boxShadow: AppDark.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Which days do classes run?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'A class is counted as held on these days whether or not anyone '
            'is scanned, so a student who does not come is marked absent even '
            'when nobody else did.',
            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var weekday = ClassSchedule.monday;
                  weekday <= ClassSchedule.sunday;
                  weekday++)
                FilterChip(
                  label: Text(_short[weekday - 1]),
                  selected: _days.contains(weekday),
                  selectedColor: AppColors.redTint,
                  checkmarkColor: AppColors.red,
                  onSelected: (selected) => _toggle(weekday, selected),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _describe(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'A day outside the schedule can still have check-ins, for a make-up '
            'class for example. They are recorded as usual.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _cancelledCard() {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final blanks = DateTime(_month.year, _month.month, 1).weekday % 7;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppDark.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDark.border),
        boxShadow: AppDark.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Training cancelled',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap any date to mark training cancelled. That day is not counted '
            'as present or absent, even if it is a regular class weekday. Tap '
            'again to put it back.',
            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
              ),
              Expanded(
                child: Text(
                  '${_monthNames[_month.month - 1]} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
              ),
            ],
          ),
          Row(
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
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (var i = 0; i < blanks; i++) const SizedBox.shrink(),
              for (var day = 1; day <= daysInMonth; day++)
                _cancelledDayCell(
                  DateTime(_month.year, _month.month, day),
                  today,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _legend(),
        ],
      ),
    );
  }

  /// What the colours in the calendar above mean.
  Widget _legend() {
    Widget item(Color? fill, String label, {Color? border, double width = 1}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(4),
              border: border == null
                  ? Border.all(color: AppColors.border)
                  : Border.all(color: border, width: width),
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
        item(AppColors.cancelled, 'Cancelled', border: AppColors.cancelled),
        item(null, 'Class day'),
        item(null, 'Today', border: AppColors.black, width: 1.5),
      ],
    );
  }

  Widget _cancelledDayCell(DateTime date, DateTime today) {
    final key = ClassSchedule.dayKey(date);
    final cancelled = _cancelled.contains(key);
    final isToday = date == today;
    final scheduled = _days.contains(date.weekday);

    return Semantics(
      button: true,
      selected: cancelled,
      label: '${_monthNames[date.month - 1]} ${date.day}'
          '${cancelled ? ', training cancelled' : ''}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleCancelled(date),
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              color: cancelled ? AppColors.cancelled : null,
              borderRadius: BorderRadius.circular(10),
              border: isToday && !cancelled
                  ? Border.all(color: AppColors.black, width: 1.5)
                  : scheduled && !cancelled
                  ? Border.all(color: AppColors.border)
                  : null,
            ),
            child: Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: cancelled || isToday
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: cancelled
                      ? AppColors.onCancelled
                      : AppColors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleCancelled(DateTime date) async {
    final key = ClassSchedule.dayKey(date);
    final previous = {..._cancelled};
    final next = {..._cancelled};
    if (!next.add(key)) next.remove(key);
    setState(() {
      _cancelled = next;
      _cancelledChanged = true;
    });
    try {
      await _schedule.saveCancelled(next);
      if (!mounted) return;
      // Say what happened and offer to take it back: a stray tap on a yellow
      // day would otherwise silently turn that day back into an absence for
      // everyone.
      final nowCancelled = next.contains(key);
      final when =
          '${_short[date.weekday - 1]}, ${_monthNames[date.month - 1]} '
          '${date.day}, ${date.year}';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              nowCancelled
                  ? 'Training cancelled on $when.'
                  : 'Cancellation removed for $when.',
            ),
            // A snackbar with an action stays until it is tapped unless
            // `persist` is switched off. Undo is a quick "oops" button, so the
            // message goes away after two seconds.
            persist: false,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => _toggleCancelled(date),
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      setState(() => _cancelled = previous);
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

  Widget _buildSaveBar() {
    return AppActionBar(
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _loaded && !_saving ? _save : null,
          child: const Text('Save'),
        ),
      ),
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
