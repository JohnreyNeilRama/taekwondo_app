import 'package:flutter/material.dart';

import '../models/student.dart';
import '../services/student_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_header.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/search_field.dart';
import '../widgets/student_avatar.dart';
import 'add_student_screen.dart';
import 'student_detail_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final StudentStorage _storage = StudentStorage();
  final List<Student> _students = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Reads the registry from the database so records survive app restarts.
  /// Never leaves the screen stuck on the loading spinner: a database failure
  /// shows a message instead.
  Future<void> _loadStudents() async {
    try {
      final students = await _storage.loadStudents();
      if (!mounted) return;
      setState(() {
        _students
          ..clear()
          ..addAll(students);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not load saved records from this device. '
            'Records added now are still kept while the app is open.',
          ),
        ),
      );
    }
  }

  /// Tells the user a change could not be saved, instead of dropping it
  /// silently.
  void _saveFailed() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not save changes to this device. Please try again.',
        ),
      ),
    );
  }

  List<Student> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _students;
    bool matches(Student s) =>
        s.name.toLowerCase().contains(q) ||
        s.nickname.toLowerCase().contains(q) ||
        s.schoolName.toLowerCase().contains(q) ||
        s.cellphoneNo.toLowerCase().contains(q);
    return _students.where(matches).toList();
  }

  /// Opens the information sheet for a new student and saves what comes back.
  /// The database mints the registry number and returns the saved record, so
  /// the card shows the id every later change goes through.
  Future<void> _addStudent() async {
    final student = await Navigator.of(context).push<Student>(
      MaterialPageRoute(builder: (_) => const AddStudentScreen()),
    );
    if (student == null || !mounted) return;
    try {
      final saved = await _storage.insert(student);
      if (!mounted) return;
      setState(() => _students.add(saved));
    } catch (_) {
      _saveFailed();
    }
  }

  /// Opens the detail screen and applies whatever came back: an
  /// updated [Student] after editing, or `'delete'` after a confirmed
  /// deletion from the detail screen.
  Future<void> _openStudent(Student student) async {
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(builder: (_) => StudentDetailScreen(student: student)),
    );
    if (result == null || !mounted) return;
    if (result is Student) {
      await _applyEdit(result);
    } else if (result == 'delete') {
      // The detail screen has already obtained delete confirmation,
      // so no second dialog is shown here.
      await _performDelete(student);
    }
  }

  /// Opens the form directly in edit mode and applies the returned
  /// record, mirroring the edit flow of the detail screen.
  Future<void> _editStudent(Student student) async {
    final updated = await Navigator.of(context).push<Student>(
      MaterialPageRoute(builder: (_) => AddStudentScreen(initial: student)),
    );
    if (updated == null || !mounted) return;
    await _applyEdit(updated);
  }

  /// Writes an edited record back through the database and shows it on the
  /// card. Students are matched by id rather than by object identity, so the
  /// right row is updated even after a rename.
  Future<void> _applyEdit(Student updated) async {
    final index = _students.indexWhere((s) => s.id == updated.id);
    if (index == -1) return;
    try {
      await _storage.update(updated);
    } catch (_) {
      _saveFailed();
      return;
    }
    if (!mounted) return;
    setState(() => _students[index] = updated);
  }

  Future<bool> _confirmDelete(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete student?'),
        content: Text(
          '${student.name} will be removed from the registry permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// Removes [student] from the registry and offers an Undo snackbar that puts
  /// them back.
  ///
  /// The database also takes the student's promotion record and achievements
  /// with the row (the foreign keys cascade), so the storage layer hands back
  /// a snapshot of everything they owned: that snapshot is what Undo restores,
  /// with the original id and registry number.
  Future<void> _performDelete(Student student) async {
    final id = student.id;
    final index = _students.indexWhere((s) => s.id == id);
    if (id == null || index == -1) return;
    final DeletedStudent deleted;
    try {
      deleted = await _storage.delete(id);
    } catch (_) {
      _saveFailed();
      return;
    }
    if (!mounted) return;
    setState(() => _students.removeAt(index));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${student.name} deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _undoDelete(deleted),
          ),
        ),
      );
  }

  /// Puts a deleted student, their promotion record and their achievements
  /// back, then re-reads the registry so the list is exactly what is saved.
  Future<void> _undoDelete(DeletedStudent deleted) async {
    try {
      await _storage.restore(deleted);
    } catch (_) {
      _saveFailed();
      return;
    }
    await _loadStudents();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  /// Search box and the Add Student action on a single row, styled and laid
  /// out the same way as the Achievement page's search + add row.
  Widget _searchAndAddRow(bool hasQuery) {
    return Row(
      children: [
        Expanded(
          child: AppSearchField(
            controller: _searchController,
            hintText: 'Search name, nickname, school, contact',
            onChanged: (value) => setState(() => _query = value),
            hasQuery: hasQuery,
            onClear: _clearSearch,
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: _addStudent,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: const Text('+ Add Student'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final hasQuery = _query.trim().isNotEmpty;
    final count = results.length;
    final countLabel = hasQuery
        ? '$count result${count == 1 ? '' : 's'} for "${_query.trim()}"'
        : '$count record${count == 1 ? '' : 's'}';

    return Column(
      children: [
        const BrandHeader(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'All Students',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                countLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              // The search box sits at the bottom of the header block, beside
              // the Add Student action, matching the Achievement page layout.
              _searchAndAddRow(hasQuery),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (results.isEmpty)
                EmptyStateCard(
                  icon: Icons.groups_outlined,
                  title: 'No student records found.',
                  message: 'Try a different search, or add a new student to start the registry.',
                  actionLabel: 'Add Student',
                  onAction: _addStudent,
                )
              else
                for (final student in results)
                  Dismissible(
                    key: ValueKey(student.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => _confirmDelete(student),
                    onDismissed: (_) => _performDelete(student),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                      ),
                    ),
                    child: _StudentCard(
                      student: student,
                      onView: () => _openStudent(student),
                      onEdit: () => _editStudent(student),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Card for one student, styled after the designed registry list: the saved
/// 1 x 1 picture (the initials until one is uploaded), name, nickname,
/// `TKD-####` badge, school / contact rows and View / Edit actions.
class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.onView,
    required this.onEdit,
  });

  final Student student;
  final VoidCallback onView;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final contact = student.cellphoneNo.isNotEmpty
        ? student.cellphoneNo
        : student.telephoneNos;
    return GestureDetector(
      onTap: onView,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StudentAvatar(
                  student: student,
                  size: 56,
                  borderRadius: 14,
                  initialsFontSize: 18,
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
                      if (student.nickname.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '"${student.nickname}"',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.redTint,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          student.studentNo,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _infoRow('School', student.schoolName),
            _infoRow('Contact', contact),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onView,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.black,
                      backgroundColor: Colors.white,
                      minimumSize: const Size(0, 40),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('View'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onEdit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Edit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// A gray label (`School`, `Contact`) with its value next to it.
  /// Hidden entirely when [value] is empty so cards stay compact.
  Widget _infoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.black),
            ),
          ),
        ],
      ),
    );
  }
}
