import 'package:flutter/material.dart';

import '../models/belt.dart';
import '../models/promotion_record.dart';
import '../models/student.dart';
import '../services/promotion_storage.dart';
import '../services/student_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_header.dart';
import '../widgets/empty_state_card.dart';
import 'promotion_detail_screen.dart';
import 'promotion_form_screen.dart';
import 'student_picker_screen.dart';

/// Belt / promotion records for students already in the registry.
///
/// "Add Student" never creates a student: it opens a picker over the
/// existing registry, then a form for the belt and last promotion date.
class PromotionScreen extends StatefulWidget {
  const PromotionScreen({super.key});

  @override
  State<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends State<PromotionScreen> {
  final PromotionStorage _promotionStorage = PromotionStorage();
  final StudentStorage _studentStorage = StudentStorage();
  final TextEditingController _searchController = TextEditingController();

  List<PromotionRecord> _records = [];
  List<Student> _students = [];
  bool _loading = true;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Reads both the registry and the promotion records. The student list is
  /// only used to resolve names and to populate the picker.
  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _promotionStorage.loadRecords(),
        _studentStorage.loadStudents(),
      ]);
      if (!mounted) return;
      final students = results[1] as List<Student>;
      final records = (results[0] as List<PromotionRecord>)
          // Keep names in sync with the registry so a renamed student is
          // reflected on their promotion record immediately.
          .map(
            (r) => r.copyWith(
              studentName: _nameFor(students, r.studentNo) ?? r.studentName,
              // Records saved before the grade-based curriculum keep their
              // original belt name; mapping it here keeps them on the right
              // Quick Card and prefills the form correctly when edited.
              belt: BeltCatalog.normalize(r.belt),
            ),
          )
          .toList();
      setState(() {
        _students = students;
        _records = records;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Could not load promotion records from this device.');
    }
  }

  static String? _nameFor(List<Student> students, String studentNo) {
    for (final student in students) {
      if (student.studentNo == studentNo) return student.name;
    }
    return null;
  }

  /// Persists the current records, surfacing failures instead of dropping
  /// the change silently.
  Future<void> _persist() async {
    try {
      await _promotionStorage.saveRecords(_records);
    } catch (_) {
      _toast('Could not save the promotion record. Please try again.');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  /// Picks an existing student, then records their belt information.
  Future<void> _addRecord() async {
    // The picker loads the registry itself, so this push is synchronous and
    // the screen always shows the current Students data — even for students
    // added after launch, long after this screen was built by the
    // `IndexedStack`.
    final student = await Navigator.of(context).push<Student>(
      MaterialPageRoute(builder: (_) => const StudentPickerScreen()),
    );
    if (student == null || !mounted) return;

    // A student can only hold one promotion record; selecting an existing
    // record opens it for editing instead of adding a duplicate.
    final existing = _recordFor(student.studentNo);
    final saved = await Navigator.of(context).push<PromotionRecord>(
      MaterialPageRoute(
        builder: (_) =>
            PromotionFormScreen(student: student, initial: existing),
      ),
    );
    if (saved == null || !mounted) return;
    setState(() {
      final index = _records.indexWhere((r) => r.studentNo == saved.studentNo);
      if (index == -1) {
        _records = [..._records, saved];
      } else {
        _records = [..._records]..[index] = saved;
      }
    });
    await _persist();
    _toast(
      existing == null
          ? 'Promotion saved for ${student.name}'
          : 'Promotion updated for ${student.name}',
    );
  }

  PromotionRecord? _recordFor(String studentNo) {
    for (final record in _records) {
      if (record.studentNo == studentNo) return record;
    }
    return null;
  }

  /// Opens the read-only detail view, then the form when Edit is pressed.
  Future<void> _openRecord(PromotionRecord record) async {
    final result = await Navigator.of(context).push<PromotionRecord>(
      MaterialPageRoute(builder: (_) => PromotionDetailScreen(record: record)),
    );
    if (result == null || !mounted) return;

    final student =
        _studentFor(result.studentNo) ??
        Student(name: result.studentName, studentNo: result.studentNo);
    final saved = await Navigator.of(context).push<PromotionRecord>(
      MaterialPageRoute(
        builder: (_) => PromotionFormScreen(student: student, initial: result),
      ),
    );
    if (saved == null || !mounted) return;
    setState(() {
      final index = _records.indexWhere((r) => r.studentNo == saved.studentNo);
      if (index != -1) {
        _records = [..._records]..[index] = saved;
      }
    });
    await _persist();
    _toast('Promotion updated');
  }

  Student? _studentFor(String studentNo) {
    for (final student in _students) {
      if (student.studentNo == studentNo) return student;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Column(
      children: [
        const BrandHeader(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Promotion Test Record',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              // The Quick Cards always sit above the search box and the Add
              // Student button, so all six belt colours stay visible even
              // with no students and no promotion records yet.
              _beltSummary(),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _searchAndAddRow(),
                const SizedBox(height: 16),
                if (results.isEmpty)
                  EmptyStateCard(
                    icon: Icons.emoji_events_outlined,
                    title: _query.trim().isEmpty
                        ? 'No promotion records yet'
                        : 'No matching students',
                    message: _query.trim().isNotEmpty
                        ? 'Try a different name or nickname.'
                        : (_students.isEmpty
                              ? 'Add a student on the Students page first, '
                                    'then record their belt here.'
                              : 'Select a student from your registry to record '
                                    'their current belt and last promotion date.'),
                    actionLabel: _query.trim().isEmpty ? 'Add Student' : null,
                    onAction: _addRecord,
                  )
                else
                  for (final group in _grouped(results)) ...[
                    _GroupHeading(
                      heading: group.heading,
                      count: group.records.length,
                    ),
                    for (final record in group.records)
                      _RecordCard(
                        record: record,
                        student: _studentFor(record.studentNo),
                        onTap: () => _openRecord(record),
                      ),
                  ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Records matching the current search, in the order the belts progress.
  List<PromotionRecord> get _results {
    final query = _query.trim().toLowerCase();
    final matches = query.isEmpty
        ? List<PromotionRecord>.from(_records)
        : _records
              .where(
                (r) =>
                    r.studentName.toLowerCase().contains(query) ||
                    r.studentNo.toLowerCase().contains(query) ||
                    r.belt.toLowerCase().contains(query),
              )
              .toList();
    matches.sort((a, b) => _rankOf(a).compareTo(_rankOf(b)));
    return matches;
  }

  /// Belt rank of a record, so the list always reads in promotion order.
  static int _rankOf(PromotionRecord record) => BeltCatalog.rankOf(record.belt);

  /// One record group per belt heading, in promotion order.
  List<({String heading, List<PromotionRecord> records})> _grouped(
    List<PromotionRecord> records,
  ) {
    final groups = <({String heading, List<PromotionRecord> records})>[];
    // Every grade doubles as its own section heading ("2nd Dan Blackbelt"),
    // so the list reads exactly like the Belt dropdown.
    for (final belt in BeltCatalog.grades) {
      final inGrade = records
          .where((r) => r.belt == belt)
          .toList(growable: false);
      if (inGrade.isNotEmpty) {
        groups.add((heading: belt, records: inGrade));
      }
    }
    // Anything with a belt that is not in the curriculum (or none at all)
    // still has to be visible, so it collects under a final heading.
    final other = records
        .where((r) => !BeltCatalog.grades.contains(r.belt))
        .toList(growable: false);
    if (other.isNotEmpty) {
      groups.add((heading: 'Unassigned Belt', records: other));
    }
    return groups;
  }

  /// The Quick Cards: one card per belt colour, strongest first, and always
  /// all six of them. Grades of the same colour are counted together, so
  /// every Dan rank lands on "Black Belts" and both Brown grades on "Brown
  /// Belts". A colour nobody holds yet simply reads 0.
  Widget _beltSummary() {
    final belts = [for (final record in _records) record.belt];
    return SizedBox(
      // Tall enough for a two-line family label plus the count, so the cards
      // never overflow on narrow phones.
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: BeltCatalog.groups.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final group = BeltCatalog.groups[index];
          return _BeltTile(
            label: group.label,
            count: group.countIn(belts),
            color: Color(group.colorValue),
          );
        },
      ),
    );
  }

  /// Search field and the Add Student button on a single row.
  Widget _searchAndAddRow() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search name, nickname...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: AppColors.muted,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.muted,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: AppColors.surface,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: _addRecord,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Student'),
        ),
      ],
    );
  }
}

/// Section heading between belt groups, e.g. "1st Dan Blackbelt".
class _GroupHeading extends StatelessWidget {
  const _GroupHeading({required this.heading, required this.count});

  final String heading;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              heading,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.iconCircle,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One Quick Card in the belt summary strip: the colour family and how many
/// students hold it, filled with that belt colour.
class _BeltTile extends StatelessWidget {
  const _BeltTile({
    required this.label,
    required this.count,
    required this.color,
  });

  /// Family label, e.g. `Black Belts`.
  final String label;

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Very light belts need dark text; dark belts need white text.
    final isLight = color.computeLuminance() > 0.5;
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: isLight ? Border.all(color: AppColors.border) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: isLight ? AppColors.black : Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isLight ? AppColors.black : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// One promotion record in the list: name, belt and last promotion date.
class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.student,
    required this.onTap,
  });

  final PromotionRecord record;

  /// The registry entry this promotion belongs to; may be null if the student
  /// was deleted from the Students page after the record was created.
  final Student? student;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nickname = student?.nickname ?? '';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.iconCircle,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                student?.initials ?? '?',
                style: const TextStyle(
                  fontSize: 15,
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
                    record.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                  if (nickname.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '"$nickname"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  AppChip(label: record.studentNo, emphasized: true),
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
