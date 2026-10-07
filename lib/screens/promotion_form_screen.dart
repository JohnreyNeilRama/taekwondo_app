import 'package:flutter/material.dart';

import '../models/belt.dart';
import '../models/promotion_record.dart';
import '../models/student.dart';
import '../theme/app_dark.dart';
import '../widgets/app_input.dart';
import '../widgets/app_page.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/student_avatar.dart';

/// Belt / promotion form. Pops with the saved [PromotionRecord].
///
/// This screen never creates a student: [student] always comes from the
/// existing Students registry, so no duplicate records can appear.
class PromotionFormScreen extends StatefulWidget {
  const PromotionFormScreen({super.key, required this.student, this.initial});

  /// The existing student the record belongs to, read from the registry, so it
  /// always carries the id the record is linked by.
  final Student student;

  /// Provided in edit mode to prefill the belt and date.
  final PromotionRecord? initial;

  @override
  State<PromotionFormScreen> createState() => _PromotionFormScreenState();
}

class _PromotionFormScreenState extends State<PromotionFormScreen> {
  late String _belt;
  DateTime? _date;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _belt = (initial != null && BeltCatalog.grades.contains(initial.belt))
        ? initial.belt
        : BeltCatalog.defaultGrade;
    _date = _parse(initial?.lastPromotionDate ?? '');
  }

  /// Parses the "MM/DD/YYYY" text stored on a record.
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(1990),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _date = picked);
  }

  void _save() {
    final student = widget.student;
    // The form is only ever opened for a student read from the registry, so
    // the id is set; without one there is nothing to attach the record to.
    final studentId = student.id;
    if (studentId == null) return;
    Navigator.of(context).pop(
      PromotionRecord(
        // Keeping the id saves over the record this student already has
        // instead of adding a second one.
        id: widget.initial?.id,
        studentId: studentId,
        // Display only: the saved record reads the number and the name from
        // the registry itself.
        studentNo: student.studentNo,
        studentName: student.name,
        belt: _belt,
        lastPromotionDate: _date == null ? '' : _format(_date!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: _isEditing ? 'Edit Promotion' : 'Add Promotion',
      subtitle: widget.student.name,
      bottom: _actions(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          _studentCard(),
          const SizedBox(height: 8),
          const SectionLabel('PROMOTION DETAILS'),
          const SizedBox(height: 12),
          _beltField(),
          const SizedBox(height: 16),
          _dateField(),
          const SizedBox(height: 24),
          const NoticeCard(
            icon: Icons.info_outline,
            message:
                'This record is linked to the student from your '
                'registry. No new student is created here.',
          ),
        ],
      ),
    );
  }

  /// Read-only summary of the selected registry student.
  Widget _studentCard() {
    return DarkCard(
      margin: const EdgeInsets.only(bottom: 16),
      accent: AppDark.crimson,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          StudentAvatar(
            student: widget.student,
            size: 56,
            borderRadius: 16,
            initialsFontSize: 18,
            backgroundColor: AppDark.surfaceHigh,
            initialsColor: AppDark.textSecondary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Student',
                  style: TextStyle(fontSize: 12, color: AppDark.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppDark.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                AppChip(label: widget.student.studentNo, emphasized: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _beltField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInput.label('Current / New Belt'),
        Container(
          decoration: AppInput.box(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _belt,
              isExpanded: true,
              dropdownColor: AppDark.surfaceHigh,
              borderRadius: BorderRadius.circular(16),
              icon: const Icon(Icons.expand_more, color: AppDark.icon),
              style: const TextStyle(fontSize: 15, color: AppDark.textPrimary),
              items: [
                for (final belt in BeltCatalog.grades)
                  DropdownMenuItem<String>(value: belt, child: Text(belt)),
              ],
              onChanged: (value) => setState(() => _belt = value!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInput.label('Last Promotion Date'),
        InkWell(
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
              _date == null ? 'Select date' : _format(_date!),
              style: TextStyle(
                fontSize: 15,
                color: _date == null
                    ? AppDark.textSecondary
                    : AppDark.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actions() {
    return AppActionBar(
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: CrimsonButton(
              label: _isEditing ? 'Save Changes' : 'Save Record',
              icon: Icons.check_rounded,
              expand: true,
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }
}
