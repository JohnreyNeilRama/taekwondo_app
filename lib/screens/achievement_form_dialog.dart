import 'package:flutter/material.dart';

import '../models/achievement_record.dart';
import '../models/student.dart';
import '../theme/app_theme.dart';
import '../widgets/award_chip.dart';
import '../widgets/empty_state_card.dart';
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
    _student =
        widget.student ??
        (initial == null
            ? null
            : Student(name: initial.studentName, studentNo: initial.studentNo));
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
    if (student == null || !_canSave) return;
    Navigator.of(context).pop(
      AchievementRecord(
        id: widget.initial?.id ?? _newId(),
        studentNo: student.studentNo,
        studentName: student.name,
        date: _date == null ? '' : _format(_date!),
        event: _eventController.text.trim(),
        award: _award,
      ),
    );
  }

  /// Ids only have to be unique inside this device achievement file.
  static String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              _fieldLabel('Student'),
              _studentField(),
              const SizedBox(height: 14),
              _fieldLabel('Date'),
              _dateField(),
              const SizedBox(height: 14),
              _fieldLabel('Event'),
              _eventField(),
              const SizedBox(height: 14),
              _fieldLabel('Achievement'),
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
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: AppColors.muted),
        ),
      ],
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
        ),
      ),
    );
  }

  /// Read-only summary of the student on an existing record, or a picker row
  /// that opens the registry while the student still has to be chosen.
  Widget _studentField() {
    final student = _student;
    final content = Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.iconCircle,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            student?.initials ?? '?',
            style: const TextStyle(
              fontSize: 13,
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
                student?.name ?? 'Select a student',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: student == null ? AppColors.muted : AppColors.black,
                ),
              ),
              if (student != null) ...[
                const SizedBox(height: 4),
                AppChip(label: student.studentNo),
              ],
            ],
          ),
        ),
        if (!_isEditing)
          const Icon(Icons.chevron_right, color: AppColors.muted),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: _isEditing
          ? Padding(padding: const EdgeInsets.all(12), child: content)
          : InkWell(
              onTap: _pickStudent,
              borderRadius: BorderRadius.circular(10),
              child: Padding(padding: const EdgeInsets.all(12), child: content),
            ),
    );
  }

  Widget _dateField() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          prefixIcon: const Icon(Icons.event_outlined, color: AppColors.black),
          suffixIcon: _date == null
              ? null
              : IconButton(
                  tooltip: 'Clear date',
                  icon: const Icon(Icons.close, color: AppColors.muted),
                  onPressed: () => setState(() => _date = null),
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
        child: Text(
          _date == null ? 'Select a date' : _format(_date!),
          style: TextStyle(
            fontSize: 14,
            color: _date == null ? AppColors.muted : AppColors.black,
          ),
        ),
      ),
    );
  }

  Widget _eventField() {
    return TextField(
      controller: _eventController,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        hintText: 'e.g. National Tournament',
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
        prefixIcon: const Icon(
          Icons.emoji_events_outlined,
          color: AppColors.black,
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }

  /// Gold / Silver / Bronze, shown with the medal colour of each option.
  Widget _awardField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _award,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, color: AppColors.black),
          style: const TextStyle(fontSize: 14, color: AppColors.black),
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
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  foregroundColor: AppColors.black,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _canSave ? _save : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(_isEditing ? 'Save Changes' : 'Save Record'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
