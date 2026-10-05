import 'package:flutter/material.dart';

import '../models/student.dart';
import '../theme/app_theme.dart';
import '../widgets/student_avatar.dart';
import 'add_student_screen.dart';

/// Read-only view of one student's full information sheet.
///
/// Pops with an updated [Student] after an edit, or with the string
/// `'delete'` after the delete confirmation is accepted. The students
/// list screen interprets both results.
class StudentDetailScreen extends StatelessWidget {
  const StudentDetailScreen({super.key, required this.student});

  final Student student;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete student?'),
        content: Text(
          '${student.name} will be moved to Trash. '
          'You can restore them from there.',
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
    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop('delete');
    }
  }

  Future<void> _edit(BuildContext context) async {
    final updated = await Navigator.of(context).push<Student>(
      MaterialPageRoute(builder: (_) => AddStudentScreen(initial: student)),
    );
    if (updated != null && context.mounted) {
      Navigator.of(context).pop(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionCard('STUDENT DETAILS', [
                  ('Nickname', student.nickname),
                  ('Birth Date', student.birthDate),
                  ('Sex', student.sex),
                  ('Religion', student.religion),
                  ('Status', student.status),
                  ('Cellphone No.', student.cellphoneNo),
                  ('Telephone No.', student.telephoneNos),
                  ('Email', student.email),
                  ('Home Address', student.homeAddress),
                  ('School Name', student.schoolName),
                  ('Grade / Year / Course', student.gradeYearCourse),
                  ('Company & Office Address', student.companyNameAddress),
                ]),
                const SizedBox(height: 16),
                _sectionCard('PARENTS / GUARDIAN', [
                  ("Father's Name", student.fatherName),
                  ("Father's Occupation", student.fatherOccupation),
                  ("Father's Office Address", student.fatherOfficeAddress),
                  ("Father's Contact Nos.", student.fatherContactNos),
                  ("Mother's Name", student.motherName),
                  ("Mother's Occupation", student.motherOccupation),
                  ("Mother's Office Address", student.motherOfficeAddress),
                  ("Mother's Contact Nos.", student.motherContactNos),
                  ("Guardian's Name", student.guardianName),
                  ("Guardian's Contact Nos.", student.guardianContactNos),
                ]),
                const SizedBox(height: 16),
                _sectionCard('ADDITIONAL QUESTIONS', [
                  (
                    'Previous martial arts training',
                    student.previousMartialArts,
                  ),
                  ('Other hobbies & sports', student.otherHobbiesSports),
                  ('Health conditions', student.healthConditions),
                ]),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildDeleteBar(context),
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
              StudentAvatar(
                student: student,
                size: 40,
                shape: BoxShape.circle,
                backgroundColor: AppColors.red,
                initialsColor: Colors.white,
                initialsFontSize: 13,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name.isEmpty ? 'Unnamed student' : student.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      student.cellphoneNo.isEmpty
                          ? 'Student record'
                          : student.cellphoneNo,
                      style: const TextStyle(
                        color: Color(0xFFD1D5DB),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                onPressed: () => _edit(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteBar(BuildContext context) {
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
            child: OutlinedButton.icon(
              onPressed: () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outline, size: 20),
              label: const Text('Delete Student'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                foregroundColor: AppColors.red,
                side: const BorderSide(color: AppColors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard(String title, List<(String, String)> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.red,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 16, color: AppColors.border),
            _FieldRow(label: rows[i].$1, value: rows[i].$2),
          ],
        ],
      ),
    );
  }
}

/// One "Label: value" line. Empty values are shown as an em dash so
/// the layout never collapses.
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final hasValue = value.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 148,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              hasValue ? value : '—',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: hasValue ? AppColors.black : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
