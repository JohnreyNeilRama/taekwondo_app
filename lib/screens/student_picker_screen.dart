import 'package:flutter/material.dart';

import '../models/student.dart';
import '../services/student_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_header.dart';
import '../widgets/empty_state_card.dart';

/// Lets the user pick a student that already exists in the Students
/// registry. Pops with the chosen [Student] or null when cancelled.
///
/// This screen deliberately has no "add student" action: promotion records
/// must attach to an existing record instead of creating a duplicate.
class StudentPickerScreen extends StatefulWidget {
  const StudentPickerScreen({super.key});

  @override
  State<StudentPickerScreen> createState() => _StudentPickerScreenState();
}

class _StudentPickerScreenState extends State<StudentPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final StudentStorage _storage = StudentStorage();

  /// The registry, read from the same source the Students page uses.
  List<Student> _students = [];
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
  Future<void> _load() async {
    try {
      final students = await _storage.loadStudents();
      if (!mounted) return;
      setState(() {
        _students = students;
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

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          BrandHeader(
            bottom: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search your students',
                hintStyle: const TextStyle(color: AppColors.muted),
                prefixIcon: const Icon(Icons.search, color: AppColors.black),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close, color: AppColors.muted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
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
                const Text(
                  'Select Student',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Choose from your existing records (${_students.length})',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
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
                else if (_students.isEmpty)
                  const EmptyStateCard(
                    icon: Icons.groups_outlined,
                    title: 'No students yet',
                    message:
                        'Add a student on the Students page first, then come '
                        'back to record their promotion.',
                  )
                else if (results.isEmpty)
                  EmptyStateCard(
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
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.iconCircle,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                student.initials,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
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
