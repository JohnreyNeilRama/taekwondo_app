import 'package:flutter/material.dart';

import '../models/student.dart';
import '../services/student_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_header.dart';
import '../widgets/empty_state_card.dart';
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

  /// Restores the registry saved on the device so records survive
  /// app restarts. Never leaves the screen stuck on the loading
  /// spinner: storage failures show a message instead.
  Future<void> _loadStudents() async {
    try {
      final students = await _storage.loadStudents();
      if (!mounted) return;
      // Stamp registry numbers onto records saved before numbering
      // existed, so every card can show its TKD badge.
      var next = _maxStudentNo(students) + 1;
      var changed = false;
      final numbered = <Student>[];
      for (final student in students) {
        if (student.studentNo.isEmpty) {
          changed = true;
          numbered.add(student.withStudentNo(_formatStudentNo(next++)));
        } else {
          numbered.add(student);
        }
      }
      setState(() {
        _students
          ..clear()
          ..addAll(numbered);
        _loading = false;
      });
      if (changed) await _persist();
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

  /// Persists the current registry, surfacing failures instead of
  /// silently dropping them.
  Future<void> _persist() async {
    try {
      await _storage.saveStudents(_students);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save changes to this device. Please try again.',
          ),
        ),
      );
    }
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

  Future<void> _addStudent() async {
    final student = await Navigator.of(context).push<Student>(
      MaterialPageRoute(builder: (_) => const AddStudentScreen()),
    );
    if (student == null || !mounted) return;
    final numbered = student.studentNo.isEmpty
        ? student.withStudentNo(_formatStudentNo(_maxStudentNo(_students) + 1))
        : student;
    setState(() => _students.add(numbered));
    await _persist();
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
      final index = _students.indexOf(student);
      if (index != -1) {
        setState(() => _students[index] = result);
        await _persist();
      }
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
    final index = _students.indexOf(student);
    if (index != -1) {
      setState(() => _students[index] = updated);
      await _persist();
    }
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

  /// Removes [student] from the list, persists the change and offers
  /// an Undo snackbar that restores the record at its old position.
  Future<void> _performDelete(Student student) async {
    final index = _students.indexOf(student);
    if (index == -1) return;
    setState(() => _students.removeAt(index));
    await _persist();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${student.name} deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              if (!mounted) return;
              final insertAt = index.clamp(0, _students.length);
              setState(() => _students.insert(insertAt, student));
              await _persist();
            },
          ),
        ),
      );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  /// Highest numeric part of the stored `TKD-####` numbers; 0 when none
  /// of the records carries one yet.
  int _maxStudentNo(List<Student> students) {
    var max = 0;
    for (final student in students) {
      final match = RegExp(r'^TKD-(\d+)$').firstMatch(student.studentNo);
      if (match == null) continue;
      final value = int.tryParse(match.group(1)!);
      if (value != null && value > max) max = value;
    }
    return max;
  }

  String _formatStudentNo(int number) =>
      'TKD-${number.toString().padLeft(4, '0')}';

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
        BrandHeader(
          bottom: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search name, nickname, school, contact',
              hintStyle: const TextStyle(color: AppColors.muted),
              prefixIcon: const Icon(Icons.search, color: AppColors.black),
              suffixIcon: hasQuery
                  ? IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close, color: AppColors.muted),
                      onPressed: _clearSearch,
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'All Students',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          countLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _addStudent,
                    child: const Text('+ Add Student'),
                  ),
                ],
              ),
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
                    key: ValueKey(student),
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

/// Card for one student, styled after the designed registry list:
/// square avatar with initials, name, nickname, `TKD-####` badge,
/// school / contact rows and View / Edit actions.
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
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.iconCircle,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    student.initials,
                    style: const TextStyle(
                      fontSize: 18,
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
