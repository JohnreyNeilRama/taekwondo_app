import 'package:flutter/material.dart';

import '../models/promotion_record.dart';
import '../models/student.dart';
import '../services/promotion_storage.dart';
import '../services/student_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/search_field.dart';
import '../widgets/student_avatar.dart';

/// Lets the user pick a student that already exists in the Students
/// registry. Pops with the chosen [Student] or null when cancelled.
///
/// This screen deliberately has no "add student" action: promotion records
/// must attach to an existing record instead of creating a duplicate.
/// With [StudentPickerScreen.pendingOnly] it is the Promotion page's Pending
/// list: only the registry students who have no belt yet are offered, so
/// choosing one assigns their first belt. The list is the registry minus the
/// students that have a row in `promotions`, so it is built from the same
/// database link the belt records are stored by — a student leaves it as soon
/// as their belt is saved and no student is ever duplicated.
class StudentPickerScreen extends StatefulWidget {
  const StudentPickerScreen({super.key, this.pendingOnly = false});

  /// Whether to offer only the students who have no promotion record yet.
  ///
  /// False keeps the original picker, which offers the whole registry: the
  /// achievement form picks any student from it, belt or not.
  final bool pendingOnly;

  @override
  State<StudentPickerScreen> createState() => _StudentPickerScreenState();
}

class _StudentPickerScreenState extends State<StudentPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final StudentStorage _storage = StudentStorage();
  final PromotionStorage _promotionStorage = PromotionStorage();

  /// The students on offer, read from the same source the Students page uses.
  /// In pending mode this is the registry minus everyone who already has a
  /// belt.
  List<Student> _students = [];

  /// How many students the registry holds before the pending filter, so the
  /// empty state can tell "no students at all" apart from "everyone already
  /// has a belt".
  int _registryCount = 0;
  bool _loading = true;
  bool _failed = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads the registry when the picker opens rather than when the Promotion
  /// screen was built, so students saved after app launch are always offered.
  ///
  /// In pending mode the promotion records are read as well: a student is
  /// pending exactly while they have no row in `promotions`, whichever belt
  /// they were given, so the Pending list follows the database rather than a
  /// copy of it.
  Future<void> _load() async {
    try {
      if (!widget.pendingOnly) {
        final students = await _storage.loadStudents();
        if (!mounted) return;
        setState(() {
          _students = students;
          _registryCount = students.length;
          _loading = false;
        });
        return;
      }
      final results = await Future.wait([
        _storage.loadStudents(),
        _promotionStorage.loadRecords(),
      ]);
      if (!mounted) return;
      setState(() {
        final students = results[0] as List<Student>;
        _students = _withoutBelt(students, results[1] as List<PromotionRecord>);
        _registryCount = students.length;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  /// The students of [students] that still have no belt, i.e. no promotion
  /// record pointing at their id.
  static List<Student> _withoutBelt(
    List<Student> students,
    List<PromotionRecord> records,
  ) {
    final withBelt = {for (final record in records) record.studentId};
    return [
      for (final student in students)
        if (!withBelt.contains(student.id)) student,
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Student> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _students;
    return _students
        .where(
          (s) =>
              s.name.toLowerCase().contains(q) ||
              s.studentNo.toLowerCase().contains(q) ||
              s.nickname.toLowerCase().contains(q),
        )
        .toList();
  }

  Widget _header(BuildContext context) {
    return Container(
      color: AppColors.black,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const SizedBox(width: 4),
              Text(
                widget.pendingOnly ? 'Pending Students' : 'Select Student',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Search box, styled and laid out the same way as the search field on the
  /// Achievement and Students pages.
  Widget _searchField() {
    return AppSearchField(
      controller: _searchController,
      hintText: 'Search your students',
      onChanged: (value) => setState(() => _query = value),
      hasQuery: _query.isNotEmpty,
      onClear: () {
        _searchController.clear();
        setState(() => _query = '');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _header(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.pendingOnly)
                  const Text(
                    'These students are waiting to be assigned a belt.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black,
                    ),
                  )
                else ...[
                  const Text(
                    'Select Student',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Choose from your existing records (${_students.length})',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
                const SizedBox(height: 12),
                // The search box sits at the bottom of the header block, in
                // the same style used on the Achievement and Students pages.
                _searchField(),
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_failed)
                  const EmptyStateCard(
                    icon: Icons.error_outline,
                    title: 'Could not load your students',
                    message: 'Please go back and try again.',
                  )
                else if (_registryCount == 0)
                  const EmptyStateCard(
                    icon: Icons.groups_outlined,
                    title: 'No students yet',
                    message:
                        'Add a student on the Students page first, then come '
                        'back to record their promotion.',
                  )
                else if (_students.isEmpty)
                  // Only reachable in pending mode: the registry has students,
                  // so an empty list means every one of them has a belt.
                  const EmptyStateCard(
                    icon: Icons.verified_outlined,
                    title: 'No pending students',
                    message:
                        'Every student in your registry already has a belt.',
                  )
                else if (results.isEmpty)
                  const EmptyStateCard(
                    icon: Icons.search_off,
                    title: 'No matching students.',
                    message: 'Try a different name or registry number.',
                  )
                else
                  for (final student in results)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _StudentOption(
                        student: student,
                        onTap: () => Navigator.of(context).pop(student),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One selectable registry student in the picker list.
class _StudentOption extends StatelessWidget {
  const _StudentOption({required this.student, required this.onTap});

  final Student student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            StudentAvatar(
              student: student,
              size: 44,
              borderRadius: 12,
              initialsFontSize: 15,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AppChip(label: student.studentNo),
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
