import 'package:flutter/material.dart';

import '../models/promotion_record.dart';
import '../models/student.dart';
import '../services/promotion_storage.dart';
import '../services/student_storage.dart';
import '../theme/app_dark.dart';
import '../widgets/app_page.dart';
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

  /// Search box, styled and laid out the same way as the search field on the
  /// Achievement and Promotion pages.
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

  /// What the list shows instead of students: a spinner, an error, or the
  /// reason there is nobody to pick.
  Widget? _placeholder(List<Student> results) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_failed) {
      return const EmptyStateCard(
        icon: Icons.error_outline,
        title: 'Could not load your students',
        message: 'Please go back and try again.',
      );
    }
    if (_registryCount == 0) {
      return const EmptyStateCard(
        icon: Icons.groups_outlined,
        title: 'No students yet',
        message:
            'Add a student on the Students page first, then come '
            'back to record their promotion.',
      );
    }
    if (_students.isEmpty) {
      // Only reachable in pending mode: the registry has students, so an empty
      // list means every one of them has a belt.
      return const EmptyStateCard(
        icon: Icons.verified_outlined,
        title: 'No pending students',
        message: 'Every student in your registry already has a belt.',
      );
    }
    if (results.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.search_off,
        title: 'No matching students.',
        message: 'Try a different name.',
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final placeholder = _placeholder(results);
    return AppPage(
      title: widget.pendingOnly ? 'Pending Students' : 'Select Student',
      subtitle: widget.pendingOnly
          ? null
          : 'Choose from your existing records (${_students.length})',
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
              child: widget.pendingOnly
                  ? const Text(
                      'These students are waiting to be assigned a belt.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: AppDark.textPrimary,
                      ),
                    )
                  : const Text(
                      'Select Student',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppDark.textPrimary,
                      ),
                    ),
            ),
          ),
          // The search card stays at the top while the list scrolls under it.
          SliverPersistentHeader(
            pinned: true,
            delegate: PinnedBarDelegate(child: _searchField()),
          ),
          if (placeholder != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: placeholder,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final student = results[index];
                  return _StudentOption(
                    student: student,
                    onTap: () => Navigator.of(context).pop(student),
                  );
                }, childCount: results.length),
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
    return DarkCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      accent: AppDark.crimson,
      onTap: onTap,
      child: Row(
        children: [
          StudentAvatar(
            student: student,
            size: 52,
            borderRadius: 16,
            initialsFontSize: 17,
            backgroundColor: AppDark.surfaceHigh,
            initialsColor: AppDark.textSecondary,
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
                    letterSpacing: -0.2,
                    color: AppDark.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppDark.textSecondary),
        ],
      ),
    );
  }
}
