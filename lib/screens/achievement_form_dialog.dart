import 'package:flutter/material.dart';

import '../models/achievement_record.dart';
import '../models/student.dart';
import '../theme/app_dark.dart';
import '../widgets/app_input.dart';
import '../widgets/award_chip.dart';
import '../widgets/student_avatar.dart';
import 'student_picker_screen.dart';

/// Floating form for one achievement record: student, date, event and award.
/// Pops with the saved [AchievementRecord], or null when cancelled.
///
/// The student is always taken from the existing registry (or locked to the
/// student it was opened from), so recording an achievement can never create a
/// second copy of a student.
class AchievementFormDialog extends StatefulWidget {
  const AchievementFormDialog({super.key, this.initial, this.student});

  /// Provided in edit mode to prefill every field.
  final AchievementRecord? initial;

  /// Locks the form to this registry student; used when the form is opened
  /// from that student own record screen.
  final Student? student;

  /// Shows the form and resolves to the saved record, or null when it was
  /// dismissed without saving.
  static Future<AchievementRecord?> show(
    BuildContext context, {
    AchievementRecord? initial,
    Student? student,
  }) => showDialog<AchievementRecord>(
    context: context,
    builder: (_) => AchievementFormDialog(initial: initial, student: student),
  );

  @override
  State<AchievementFormDialog> createState() => _AchievementFormDialogState();
}

class _AchievementFormDialogState extends State<AchievementFormDialog> {
  final TextEditingController _eventController = TextEditingController();

  /// The student this achievement belongs to; null until one is picked.
  Student? _student;
  DateTime? _date;
  late String _award;

  /// A record can be edited, but it can never be moved to another student: the
  /// picker is only offered while nothing has been recorded yet.
  bool get _isEditing => widget.initial != null;

  bool get _canSave =>
      _student != null && _eventController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    // In edit mode the record carries the `students.id` it belongs to, which is
    // what keeps the saved award attached to the same registry row.
    _student =
        widget.student ??
        (initial == null
            ? null
            : Student(
                id: initial.studentId,
                name: initial.studentName,
                studentNo: initial.studentNo,
              ));
    _date = _parse(initial?.date ?? '');
    _eventController.text = initial?.event ?? '';
    // Keeps Save disabled until the event is described.
    _eventController.addListener(() => setState(() {}));
    _award = (initial != null && Award.fromLabel(initial.award) != null)
        ? initial.award
        : Award.all.first.label;
  }

  @override
  void dispose() {
    _eventController.dispose();
    super.dispose();
  }

  /// Parses the `MM/DD/YYYY` text stored on a record.
  static DateTime? _parse(String value) {
    final parts = value.split('/');
    if (parts.length != 3) return null;
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (month == null || day == null || year == null) return null;
    return DateTime(year, month, day);
  }

  String _format(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
  }

  /// New records start on today, so an award is never saved without a date
  /// unless the user clears it on purpose.
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() => _date = picked);
  }

  /// Picks the student from the existing registry: the picker only lists
  /// students that are already on the Students page.
  Future<void> _pickStudent() async {
    final picked = await Navigator.of(context).push<Student>(
      MaterialPageRoute(builder: (_) => const StudentPickerScreen()),
    );
    if (picked == null || !mounted) return;
    setState(() => _student = picked);
  }

  void _save() {
    final student = _student;
    // The form only ever offers students read from the registry, so the id is
    // set: it is what attaches the award to an existing registry row instead of
    // creating a second copy of the student.
    final studentId = student?.id;
    if (student == null || studentId == null || !_canSave) return;
    Navigator.of(context).pop(
      AchievementRecord(
        // Keeping the id saves over the record being edited; a new record has
        // none until the database inserts it.
        id: widget.initial?.id,
        studentId: studentId,
        // Display only: the saved record reads the number and the name from
        // the registry itself.
        studentNo: student.studentNo,
        studentName: student.name,
        date: _date == null ? '' : _format(_date!),
        event: _eventController.text.trim(),
        award: _award,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _title(),
              const SizedBox(height: 16),
              AppInput.label('Student'),
              _studentField(),
              const SizedBox(height: 14),
              AppInput.label('Date'),
              _dateField(),
              const SizedBox(height: 14),
              AppInput.label('Event'),
              _eventField(),
              const SizedBox(height: 14),
              AppInput.label('Achievement'),
              _awardField(),
              const SizedBox(height: 20),
              _actions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _title() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _isEditing ? 'Edit Achievement' : 'Add Achievement',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: AppDark.textPrimary,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: AppDark.textSecondary),
        ),
      ],
    );
  }

  /// Read-only summary of the student on an existing record, or a picker row
  /// that opens the registry while the student still has to be chosen.
  Widget _studentField() {
    final student = _student;
    final content = Row(
      children: [
        StudentAvatar(
          student: student,
          size: 40,
          borderRadius: 12,
          initialsFontSize: 14,
          backgroundColor: AppDark.surfaceHigh,
          initialsColor: AppDark.textSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                student?.name ?? 'Select a student',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: student == null
                      ? AppDark.textSecondary
                      : AppDark.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (!_isEditing)
          const Icon(Icons.chevron_right, color: AppDark.textSecondary),
      ],
    );

    return Container(
      decoration: AppInput.box(),
      child: _isEditing
          ? Padding(padding: const EdgeInsets.all(12), child: content)
          : InkWell(
              onTap: _pickStudent,
              borderRadius: BorderRadius.circular(14),
              child: Padding(padding: const EdgeInsets.all(12), child: content),
            ),
    );
  }

  Widget _dateField() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: AppInput.decoration(
          prefixIcon: const Icon(Icons.event_outlined),
          suffixIcon: _date == null
              ? null
              : IconButton(
                  tooltip: 'Clear date',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _date = null),
                ),
        ),
        child: Text(
          _date == null ? 'Select a date' : _format(_date!),
          style: TextStyle(
            fontSize: 15,
            color: _date == null ? AppDark.textSecondary : AppDark.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _eventField() {
    return TextField(
      controller: _eventController,
      textInputAction: TextInputAction.done,
      style: const TextStyle(fontSize: 15, color: AppDark.textPrimary),
      decoration: AppInput.decoration(
        hint: 'e.g. National Tournament',
        prefixIcon: const Icon(Icons.emoji_events_outlined),
      ),
    );
  }

  /// Gold / Silver / Bronze, shown with the medal colour of each option.
  Widget _awardField() {
    return Container(
      decoration: AppInput.box(),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _award,
          isExpanded: true,
          dropdownColor: AppDark.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
          icon: const Icon(Icons.expand_more, color: AppDark.icon),
          style: const TextStyle(fontSize: 15, color: AppDark.textPrimary),
          items: [
            for (final award in Award.all)
              DropdownMenuItem<String>(
                value: award.label,
                child: AwardChip(award: award),
              ),
          ],
          onChanged: (value) => setState(() => _award = value!),
        ),
      ),
    );
  }

  Widget _actions() {
    return Column(
      children: [
        if (!_canSave)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Pick a student and describe the event to save this award.',
              style: TextStyle(fontSize: 12.5, color: AppDark.textSecondary),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _canSave ? _save : null,
                child: Text(_isEditing ? 'Save Changes' : 'Save Record'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
