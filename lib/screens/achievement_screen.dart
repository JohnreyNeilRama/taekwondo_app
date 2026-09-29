import 'package:flutter/material.dart';

import '../models/achievement_record.dart';
import '../models/student.dart';
import '../services/achievement_storage.dart';
import '../services/student_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/award_chip.dart';
import '../widgets/brand_header.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/search_field.dart';
import '../widgets/student_avatar.dart';
import 'achievement_detail_screen.dart';

/// Achievement records, listed one card per student.
///
/// The list is the registry itself: every student of the Students page shows up
/// here, including the ones without awards yet, and tapping a card opens that
/// student records, where awards are added, edited and deleted.
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
      setState(() {
        _students = results[0] as List<Student>;
        // Each record arrives with the registry number and the current name of
        // its student filled in by the database JOIN, so a rename needs no
        // synchronising here.
        _records = results[1] as List<AchievementRecord>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Could not load achievements from this device.');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  /// This student records, as handed to the detail screen.
  List<AchievementRecord> _recordsFor(int? studentId) => [
    for (final record in _records)
      if (record.studentId == studentId) record,
  ];

  /// Opens one student records, handing the detail screen only that student
  /// slice of the achievements.
  ///
  /// That screen saves each add, edit and delete on its own and calls back
  /// through [AchievementDetailScreen.onChanged], which re-reads this list.
  Future<void> _openStudent(Student student) async {
    final studentId = student.id;
    if (studentId == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AchievementDetailScreen(
          student: student,
          records: _recordsFor(studentId),
          onChanged: _load,
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
              // The search box leads the list.
              _searchBox(),
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
                    records: _recordsFor(student.id),
                    onTap: () => _openStudent(student),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  /// Full-width search box at the top of the list.
  Widget _searchBox() {
    final hasQuery = _query.trim().isNotEmpty;
    return AppSearchField(
      controller: _searchController,
      hintText: 'Search name, nickname...',
      onChanged: (value) => setState(() => _query = value),
      hasQuery: hasQuery,
      onClear: () {
        _searchController.clear();
        setState(() => _query = '');
      },
    );
  }
}

/// One student card, styled after the designed achievement list: the saved
/// 1 x 1 picture (the initials until one is uploaded), name, nickname,
/// `TKD-####` badge and the medals the student already holds.
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
            StudentAvatar(
              student: student,
              size: 52,
              borderRadius: 14,
              initialsFontSize: 16,
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
