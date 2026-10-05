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

  /// Every student's achievements, grouped once per [_load] instead of
  /// filtered out of the full list on every card built. Rebuilding this is
  /// O(n) per load; looking a student up in it is O(1), which is what keeps
  /// opening a registry of hundreds of students cheap.
  Map<int, List<AchievementRecord>> _recordsByStudent = {};
  bool _loading = true;
  String _query = '';

  /// The storage revisions this page last read. Null forces the first
  /// [_load] to fetch both tables; after that, a tab visit or a post-edit
  /// refresh only re-reads a table whose revision has actually moved on,
  /// instead of both of them every single time.
  int? _seenStudentsRevision;
  int? _seenAchievementsRevision;

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

  /// Reads the registry and the achievement records — but only the ones that
  /// actually changed since the last read.
  ///
  /// Both this page's own tab-visit refresh and the achievement detail
  /// screen's post-edit callback go through here, so the same check covers
  /// both: if a Students-page edit hasn't touched [StudentStorage.revision]
  /// and this page's own edits haven't touched [AchievementStorage.revision],
  /// there is nothing to read and the database is not touched at all.
  Future<void> _load() async {
    final needStudents = _seenStudentsRevision != StudentStorage.revision;
    final needRecords = _seenAchievementsRevision != AchievementStorage.revision;
    if (!needStudents && !needRecords) {
      if (_loading && mounted) setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        needStudents ? _studentStorage.loadStudents() : _identity(_students),
        needRecords
            ? _achievementStorage.loadRecords()
            : _identity(_records),
      ]);
      if (!mounted) return;
      setState(() {
        _students = results[0] as List<Student>;
        // Each record arrives with the registry number and the current name of
        // its student filled in by the database JOIN, so a rename needs no
        // synchronising here.
        _records = results[1] as List<AchievementRecord>;
        final byStudent = <int, List<AchievementRecord>>{};
        for (final record in _records) {
          (byStudent[record.studentId] ??= []).add(record);
        }
        _recordsByStudent = byStudent;
        _seenStudentsRevision = StudentStorage.revision;
        _seenAchievementsRevision = AchievementStorage.revision;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Could not load achievements from this device.');
    }
  }

  /// Hands [value] back unchanged, as a `Future`, so [Future.wait] above can
  /// mix a real read with a table this call does not need to re-read.
  static Future<T> _identity<T>(T value) => Future.value(value);

  /// Refreshes after the detail screen added, edited or deleted an award of
  /// [studentId]: re-reads only that student's rows and patches them into the
  /// lists already in memory, instead of reading every student's awards again.
  ///
  /// The shortcut is only taken when this one edit is provably the only thing
  /// that changed: the registry is untouched, and exactly one achievement
  /// mutation has happened since the last full read. Anything else (a student
  /// edited or deleted, a backup imported, an unexpected revision jump) falls
  /// back to [_load], which re-reads whatever actually moved on.
  Future<void> _reloadStudent(int studentId) async {
    final seen = _seenAchievementsRevision;
    final revisionNow = AchievementStorage.revision;
    final onlyThisEdit =
        seen != null &&
        seen + 1 == revisionNow &&
        _seenStudentsRevision == StudentStorage.revision;
    if (!onlyThisEdit) return _load();
    try {
      final fresh = await _achievementStorage.loadForStudent(studentId);
      if (!mounted) return;
      // Something else saved while this read was running; its rows may not be
      // in `fresh`, so do the full, always-correct read instead.
      if (AchievementStorage.revision != revisionNow) {
        await _load();
        return;
      }
      setState(() {
        _records = [
          for (final record in _records)
            if (record.studentId != studentId) record,
          ...fresh,
        ];
        if (fresh.isEmpty) {
          _recordsByStudent.remove(studentId);
        } else {
          _recordsByStudent[studentId] = fresh;
        }
        _seenAchievementsRevision = revisionNow;
      });
    } catch (_) {
      if (!mounted) return;
      _toast('Could not refresh the achievements from this device.');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  /// This student records, as handed to the detail screen.
  List<AchievementRecord> _recordsFor(int? studentId) =>
      _recordsByStudent[studentId] ?? const [];

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
          onChanged: () => _reloadStudent(studentId),
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
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Achievement Record',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
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
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
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
                        ),
                    ],
                  ),
                ),
              ),
              if (!_loading && results.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final student = results[index];
                        return _StudentCard(
                          student: student,
                          records: _recordsFor(student.id),
                          onTap: () => _openStudent(student),
                        );
                      },
                      childCount: results.length,
                    ),
                  ),
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
