import 'package:flutter/material.dart';

import '../services/class_schedule.dart';
import '../theme/app_theme.dart';

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
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Set<int>? saved;
    try {
      saved = await _schedule.load();
    } catch (_) {
      // The page still opens, empty: the owner can set the days again.
    }
    if (!mounted) return;
    setState(() {
      _days = {...?saved};
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _loaded
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [_card()],
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      bottomNavigationBar: _buildSaveBar(),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                      'Class days',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'The weekdays classes are held',
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

  Widget _card() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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

  Widget _buildSaveBar() {
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
            child: FilledButton(
              onPressed: _loaded && !_saving ? _save : null,
              child: const Text('Save'),
            ),
          ),
        ),
      ),
    );
  }
}
