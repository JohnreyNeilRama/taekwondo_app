import 'package:flutter/material.dart';

import '../models/achievement_record.dart';
import '../models/student.dart';
import '../services/achievement_storage.dart';
import '../services/student_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/award_chip.dart';
import '../widgets/brand_header.dart';
import '../widgets/empty_state_card.dart';
import 'achievement_detail_screen.dart';
import 'achievement_form_dialog.dart';

/// Achievement records, listed one card per student.
///
/// The list is the registry itself: every student of the Students page shows up
/// here, including the ones without awards yet, and tapping a card opens that
/// student records. "Add Student" never creates a student: it opens the
/// floating achievement form, which picks the student from the existing
/// registry.
class AchievementScreen extends StatefulWidget {
  const AchievementScreen({super.key, this.visits = 0});

  /// Changes every time a destination is selected in the shell. The list is
  /// built once at app launch by the `IndexedStack`, so this signal reloads it
  /// whenever the user comes back — with the students and awards that were
  /// saved in the meantime.
  final int visits;

  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen> {
  final AchievementStorage _achievementStorage = AchievementStorage();
  final StudentStorage _studentStorage = StudentStorage();
  final TextEditingController _searchController = TextEditingController();

  List<AchievementRecord> _records = [];
  List<Student> _students = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AchievementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Silent refresh: `_load` never shows the spinner again, so switching
    // destinations does not flash the list.
    if (widget.visits != oldWidget.visits) _load();
  }

  /// Reads the registry and the achievement records. The registry comes first
  /// so the list can show every student, awards or not.
  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _studentStorage.loadStudents(),
        _achievementStorage.loadRecords(),
      ]);
      if (!mounted) return;
      final students = results[0] as List<Student>;
      final records = (results[1] as List<AchievementRecord>)
          // Keep names in sync with the registry, so a renamed student is
          // reflected on their awards immediately.
          .map(
            (r) => r.copyWith(
              studentName: _nameFor(students, r.studentNo) ?? r.studentName,
            ),
          )
          .toList();
      setState(() {
        _students = students;
        _records = records;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Could not load achievements from this device.');
    }
  }

  static String? _nameFor(List<Student> students, String studentNo) {
    for (final student in students) {
      if (student.studentNo == studentNo) return student.name;
    }
    return null;
  }

  /// Persists the current records, surfacing failures instead of dropping the
  /// change silently.
  Future<void> _persist() async {
    try {
      await _achievementStorage.saveRecords(_records);
    } catch (_) {
      _toast('Could not save the achievement. Please try again.');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  /// This student records, as handed to the detail screen.
  List<AchievementRecord> _recordsFor(String studentNo) => [
    for (final record in _records)
      if (record.studentNo == studentNo) record,
  ];

  /// Merges the slice edited on the detail screen back into the full list and
  /// saves it.
  Future<void> _replaceRecordsFor(
    String studentNo,
    List<AchievementRecord> records,
  ) async {
    setState(() {
      _records = [
        for (final record in _records)
          if (record.studentNo != studentNo) record,
        ...records,
      ];
    });
    await _persist();
  }

  /// Opens the floating achievement form. The student is chosen inside the
  /// form from the existing registry; no student is ever created here.
  Future<void> _addAchievement() async {
    final saved = await AchievementFormDialog.show(context);
    if (saved == null || !mounted) return;
    setState(() => _records = _upsert(saved));
    await _persist();
    _toast('Achievement saved for ${saved.studentName}');
  }

  /// Replaces an edited record in place, or appends a new one.
  List<AchievementRecord> _upsert(AchievementRecord saved) {
    final index = _records.indexWhere((r) => r.id == saved.id);
    if (index == -1) return [..._records, saved];
    return [..._records]..[index] = saved;
  }

  /// Opens one student records, handing the detail screen only that student
  /// slice of the achievements.
  Future<void> _openStudent(Student student) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AchievementDetailScreen(
          student: student,
          records: _recordsFor(student.studentNo),
          onChanged: (records) =>
              _replaceRecordsFor(student.studentNo, records),
        ),
      ),
    );
  }

  /// Students matching the search box, in registry order. The search covers
  /// name, nickname, school and student number.
  List<Student> get _results {
    final query = _query.trim().toLowerCase();
    return _students.where((student) {
      return query.isEmpty ||
          student.name.toLowerCase().contains(query) ||
          student.nickname.toLowerCase().contains(query) ||
          student.schoolName.toLowerCase().contains(query) ||
          student.studentNo.toLowerCase().contains(query);
    }).toList();
  }

  /// `3 students - 5 achievement records`. Uses an escaped middot so the source
  /// stays plain ASCII.
  String _countLabel(int count, int total) {
    final students = '$count student${count == 1 ? '' : 's'}';
    final records = '$total achievement record${total == 1 ? '' : 's'}';
    return '$students \u00B7 $records';
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final total = _records.length;
    return Column(
      children: [
        const BrandHeader(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Achievement Record',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              // The search box sits where the medal filter used to be, on the
              // same row as the Add Student action.
              _searchAndAddRow(),
              const SizedBox(height: 20),
              const Text(
                'List of Students',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _countLabel(results.length, total),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_students.isEmpty)
                const EmptyStateCard(
                  icon: Icons.groups_outlined,
                  title: 'No students yet',
                  message:
                      'Add a student on the Students page first, then come '
                      'back to record their achievement.',
                )
              else if (results.isEmpty)
                const EmptyStateCard(
                  icon: Icons.search_off,
                  title: 'No matching students',
                  message: 'Try a different name, nickname or school.',
                )
              else
                for (final student in results)
                  _StudentCard(
                    student: student,
                    records: _recordsFor(student.studentNo),
                    onTap: () => _openStudent(student),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  /// Search box and the Add Student action on a single row, in the place the
  /// medal filter used to occupy: the search field now leads the list.
  Widget _searchAndAddRow() {
    final hasQuery = _query.trim().isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search name, nickname...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: AppColors.muted,
                ),
                suffixIcon: hasQuery
                    ? IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.muted,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: _addAchievement,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: const Text('+ Add Student'),
        ),
      ],
    );
  }
}

/// One student card, styled after the designed achievement list: square avatar
/// with initials, name, nickname, `TKD-####` badge and the medals the student
/// already holds.
class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.records,
    required this.onTap,
  });

  final Student student;

  /// Only this student achievements, used for the medal chips.
  final List<AchievementRecord> records;

  final VoidCallback onTap;

  /// How many of each medal this student holds.
  Map<Award, int> get _medalCounts {
    final counts = <Award, int>{};
    for (final record in records) {
      final medal = record.medal;
      if (medal == null) continue;
      counts[medal] = (counts[medal] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final counts = _medalCounts;
    final nickname = student.nickname;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.iconCircle,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                student.initials,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
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
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      AppChip(label: student.studentNo, emphasized: true),
                      for (final award in Award.all)
                        if ((counts[award] ?? 0) > 0)
                          AwardChip(award: award, count: counts[award]),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
