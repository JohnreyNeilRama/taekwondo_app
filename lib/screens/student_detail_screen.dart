import 'package:flutter/material.dart';

import '../models/student.dart';
import '../services/attendance_storage.dart';
import '../theme/app_dark.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page.dart';
import '../widgets/attendance_history_card.dart';
import '../widgets/registry_header.dart';
import '../widgets/student_avatar.dart';
import 'add_student_screen.dart';
import 'student_attendance_calendar_screen.dart';
import 'student_qr_screen.dart';

/// Read-only view of one student's full information sheet.
///
/// Pops with an updated [Student] after an edit, or with the string
/// `'delete'` after the delete confirmation is accepted. The students
/// list screen interprets both results.
class StudentDetailScreen extends StatefulWidget {
  const StudentDetailScreen({super.key, required this.student});

  final Student student;

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  Student get student => widget.student;

  /// Bumped when the calendar may have added or removed a check-in, so the
  /// attendance card below reloads.
  int _attendanceStamp = 0;

  /// The sections of the sheet that are open, by title. The student's own
  /// details open first; the parents' and the extra questions stay hidden until
  /// the owner asks to see them, and any section can be hidden again with the
  /// same tap.
  final Set<String> _openSections = {'STUDENT DETAILS'};

  void _toggleSection(String title) {
    setState(() {
      if (!_openSections.add(title)) _openSections.remove(title);
    });
  }

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

  /// Opens this student's QR code, the one scanned to record attendance.
  void _showQr(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => StudentQrScreen(student: student)),
    );
  }

  /// Opens this student's attendance calendar: present and absent days by
  /// month. Reloads the attendance card afterwards, in case a day was added
  /// or removed by hand.
  Future<void> _showCalendar(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StudentAttendanceCalendarScreen(student: student),
      ),
    );
    if (!mounted) return;
    setState(() => _attendanceStamp = AttendanceStorage.revision);
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
    return AppPage(
      title: student.name.isEmpty ? 'Unnamed student' : student.name,
      subtitle: student.cellphoneNo.isEmpty
          ? 'Student record'
          : student.cellphoneNo,
      actions: [
        HeaderIconButton(
          icon: Icons.qr_code_2,
          tooltip: 'QR code',
          onPressed: () => _showQr(context),
        ),
        HeaderIconButton(
          icon: Icons.calendar_month_outlined,
          tooltip: 'Attendance calendar',
          onPressed: student.id == null ? null : () => _showCalendar(context),
        ),
        HeaderIconButton(
          icon: Icons.edit_outlined,
          tooltip: 'Edit',
          onPressed: () => _edit(context),
        ),
      ],
      bottom: _buildDeleteBar(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          _hero(),
          const SizedBox(height: 16),
          if (student.id != null) ...[
            AttendanceHistoryCard(
              key: ValueKey(_attendanceStamp),
              studentId: student.id!,
              studentName: student.name,
            ),
            const SizedBox(height: 16),
          ],
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
            ('Previous martial arts training', student.previousMartialArts),
            ('Other hobbies & sports', student.otherHobbiesSports),
            ('Health conditions', student.healthConditions),
          ]),
        ],
      ),
    );
  }

  /// The top of the page: the student's picture, large, beside a short
  /// profile label (and the nickname, when there is one). The name is already
  /// in the header, so it is not repeated here.
  Widget _hero() {
    return DarkCard(
      accent: AppDark.crimson,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          StudentAvatar(
            student: student,
            size: 76,
            borderRadius: 22,
            initialsFontSize: 26,
            backgroundColor: AppDark.surfaceHigh,
            initialsColor: AppDark.rose,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Student profile',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppDark.textPrimary,
                  ),
                ),
                if (student.nickname.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '"${student.nickname}"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: AppDark.rose,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteBar(BuildContext context) {
    return AppActionBar(
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _confirmDelete(context),
          icon: const Icon(Icons.delete_outline, size: 20),
          label: const Text('Delete Student'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppDark.rose,
            side: BorderSide(color: AppDark.crimson.withValues(alpha: 0.6)),
            backgroundColor: AppDark.crimson.withValues(alpha: 0.08),
          ),
        ),
      ),
    );
  }

  /// One section of the sheet. Its title row is a button that shows or hides
  /// the rows below it. A hidden section builds none of its rows, so nothing in
  /// it is on screen, read out, or found by a search of the page until it is
  /// opened.
  Widget _sectionCard(String title, List<(String, String)> rows) {
    final open = _openSections.contains(title);
    return DarkCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: open,
            child: InkWell(
              onTap: () => _toggleSection(title),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SectionLabel(title),
                          if (!open) ...[
                            const SizedBox(height: 4),
                            const Text(
                              'Hidden \u00B7 tap to show',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppDark.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 28,
                        color: AppDark.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < rows.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 16, color: AppDark.border),
                          _FieldRow(label: rows[i].$1, value: rows[i].$2),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
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
              style: const TextStyle(
                fontSize: 13,
                color: AppDark.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              hasValue ? value : '—',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: hasValue ? AppDark.textPrimary : AppDark.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
