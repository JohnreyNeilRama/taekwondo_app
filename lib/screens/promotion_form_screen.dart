import 'package:flutter/material.dart';

import '../models/belt.dart';
import '../models/promotion_record.dart';
import '../models/student.dart';
import '../theme/app_theme.dart';
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
        : BeltCatalog.grades.first;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                _studentCard(),
                const SizedBox(height: 20),
                const Text(
                  'PROMOTION DETAILS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 12),
                _beltField(),
                const SizedBox(height: 14),
                _dateField(),
                const SizedBox(height: 20),
                const NoticeCard(
                  icon: Icons.info_outline,
                  message:
                      'This record is linked to the student from your '
                      'registry. No new student is created here.',
                ),
              ],
            ),
          ),
          _actions(),
        ],
      ),
    );
  }

  Widget _header() {
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
                _isEditing ? 'Edit Promotion' : 'Add Promotion',
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

  /// Read-only summary of the selected registry student.
  Widget _studentCard() {
    return SectionCard(
      icon: Icons.person_outline,
      title: 'Student',
      subtitle: 'Selected from your Students registry',
      showDivider: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            StudentAvatar(
              student: widget.student,
              size: 46,
              borderRadius: 12,
              initialsFontSize: 16,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.student.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AppChip(label: widget.student.studentNo),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _beltField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            'Current / New Belt',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _belt,
              isExpanded: true,
              icon: const Icon(Icons.expand_more, color: AppColors.black),
              style: const TextStyle(fontSize: 14, color: AppColors.black),
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
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            'Last Promotion Date',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ),
        InkWell(
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
              prefixIcon: const Icon(
                Icons.event_outlined,
                color: AppColors.black,
              ),
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
              _date == null ? 'Select date' : _format(_date!),
              style: TextStyle(
                fontSize: 14,
                color: _date == null ? AppColors.muted : AppColors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actions() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                child: FilledButton(
                  onPressed: _save,
                  child: Text(_isEditing ? 'Save Changes' : 'Save Record'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
