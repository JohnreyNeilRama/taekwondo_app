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
import 'student_qr_screen.dart';
import 'trash_screen.dart';

/// The stored name split for display and sorting: the family name and the
/// given names.
///
/// The information sheet records one free-text name ("Juan Miguel Dela Cruz"),
/// so the family name is worked out here: the last word, joined with the word
/// before it whenever that word is a surname particle ("Dela Cruz",
/// "Del Rosario", "San Pedro"). A single-word name is taken as the given name,
/// and a name that already reads "Family, Given" is left as it is. Nothing is
/// stored differently — this only decides how a name is shown and ordered.
({String family, String given}) splitStudentName(String fullName) {
  final name = fullName.trim();
  if (name.isEmpty) return (family: '', given: '');

  // A name already written with a comma is understood as "Family, Given".
  final comma = name.indexOf(',');
  if (comma != -1) {
    return (
      family: name.substring(0, comma).trim(),
      given: name.substring(comma + 1).trim(),
    );
  }

  final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length == 1) return (family: '', given: words.first);

  // Walk back over the surname particles: the family name is the last word plus
  // every particle directly before it.
  var start = words.length - 1;
  while (start - 1 >= 0 &&
      _surnameParticles.contains(_plain(words[start - 1]))) {
    start--;
  }
  return (
    family: words.sublist(start).join(' '),
    given: words.sublist(0, start).join(' '),
  );
}

/// A word lowered and stripped of a trailing dot, so `Sta.` matches `sta`.
String _plain(String word) => word.toLowerCase().replaceAll('.', '');

/// Words that belong to the family name that follows them, e.g. the `Dela` of
/// `Dela Cruz`. Kept to the particles common in Filipino and Spanish names, so a
/// middle name is never swallowed into the surname.
const Set<String> _surnameParticles = {
  'de',
  'del',
  'dela',
  'delas',
  'delos',
  'della',
  'delle',
  'di',
  'da',
  'das',
  'dos',
  'la',
  'las',
  'los',
  'le',
  'san',
  'santa',
  'santo',
  'sta',
  'sto',
};

/// The name the card shows: family name first, e.g. `Dela Cruz, Juan Miguel`.
/// A name that cannot be split is shown unchanged.
String displayStudentName(String fullName) {
  final parts = splitStudentName(fullName);
  if (parts.family.isEmpty) return parts.given;
  if (parts.given.isEmpty) return parts.family;
  return '${parts.family}, ${parts.given}';
}

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key, this.visits = 0});

  /// Tests that are about the registry list switch off the QR screen that opens
  /// after a student is added, so the list is on screen as soon as the form
  /// closes. The app never sets it.
  static bool debugSkipQrAfterAdd = false;

  /// Changes every time a destination is selected in the shell. The screen is
  /// built once at app launch by the `IndexedStack`, so this signal is what
  /// makes it look at the registry again when the user comes back — with the
  /// students an import added in the meantime. Without it the list would keep
  /// showing what it read at launch until the app was restarted.
  final int visits;

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final StudentStorage _storage = StudentStorage();
  final List<Student> _students = [];
  bool _loading = true;
  String _query = '';

  /// The [StudentStorage.revision] this list was last read at. Null until the
  /// first read succeeds. A tab visit only re-reads the registry when the
  /// revision has moved on, so coming back to an unchanged list costs nothing.
  int? _seenRevision;

  /// Counts this screen's own add / edit / delete / undo actions, bumped when
  /// one starts and again when it changes the list. A read that was already in
  /// flight while that happened may hold the registry from before the change,
  /// so [_loadStudents] throws such a read away and starts again instead of
  /// letting it overwrite the edit.
  int _localWrites = 0;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void didUpdateWidget(StudentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Silent refresh: `_loadStudents` never shows the spinner again, so
    // switching tabs does not flash the list, and the search box is kept.
    if (widget.visits != oldWidget.visits &&
        _seenRevision != StudentStorage.revision) {
      _loadStudents();
    }
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
    final writesBefore = _localWrites;
    // Taken before the read: a change that lands while it runs leaves the
    // revision ahead of this one, so the next visit reads again.
    final revisionBefore = StudentStorage.revision;
    var stale = false;
    try {
      final students = await _storage.loadStudents();
      if (!mounted) return;
      if (writesBefore != _localWrites) {
        // An add / edit / delete ran on this screen during the read, so
        // `students` may predate it. Never show it; read again below.
        stale = true;
      } else {
        setState(() {
          _students
            ..clear()
            ..addAll(students);
          _loading = false;
        });
        _seenRevision = revisionBefore;
      }
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
    if (stale) await _loadStudents();
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

  /// The students on screen: the search box's filter, ordered by family name
  /// (A-Z) and then given name. Building and sorting a fresh list on every read
  /// is what makes the order update by itself after an add or an edit; the
  /// stored [_students], and every TKD number, is left exactly as it is.
  List<Student> get _results {
    final q = _query.trim().toLowerCase();
    final list = q.isEmpty
        ? List<Student>.of(_students)
        : _students.where((s) => _matches(s, q)).toList();
    list.sort(_byFamilyName);
    return list;
  }

  bool _matches(Student s, String q) =>
      s.name.toLowerCase().contains(q) ||
      s.nickname.toLowerCase().contains(q) ||
      s.schoolName.toLowerCase().contains(q) ||
      s.cellphoneNo.toLowerCase().contains(q) ||
      s.studentNo.toLowerCase().contains(q);

  /// Family name first, given name as the tie-breaker, and the registry number
  /// only to settle an exact tie, so two students with the same name keep a
  /// fixed order instead of swapping between builds.
  int _byFamilyName(Student a, Student b) {
    final aName = splitStudentName(a.name);
    final bName = splitStudentName(b.name);
    final byFamily = aName.family.toLowerCase().compareTo(
      bName.family.toLowerCase(),
    );
    if (byFamily != 0) return byFamily;
    final byGiven = aName.given.toLowerCase().compareTo(
      bName.given.toLowerCase(),
    );
    if (byGiven != 0) return byGiven;
    return a.studentNo.compareTo(b.studentNo);
  }

  /// Opens the information sheet for a new student and saves what comes back.
  /// The database mints the registry number and returns the saved record, so
  /// the card shows the id every later change goes through.
  Future<void> _addStudent() async {
    final student = await Navigator.of(context).push<Student>(
      MaterialPageRoute(builder: (_) => const AddStudentScreen()),
    );
    if (student == null || !mounted) return;
    _localWrites++;
    Student? added;
    try {
      final saved = await _storage.insert(student);
      if (!mounted) return;
      setState(() {
        _localWrites++;
        _students.add(saved);
      });
      added = saved;
    } catch (_) {
      _saveFailed();
    }
    // The student is saved: show their QR code right away, so it can be shown,
    // printed or screenshotted before moving on. It is outside the try above on
    // purpose, so a problem opening this screen is never reported as a failed
    // save.
    if (added == null || !mounted || StudentsScreen.debugSkipQrAfterAdd) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StudentQrScreen(student: added!, justSaved: true),
      ),
    );
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
    _localWrites++;
    try {
      await _storage.update(updated);
    } catch (_) {
      _saveFailed();
      return;
    }
    if (!mounted) return;
    setState(() {
      _localWrites++;
      _students[index] = updated;
    });
  }

  Future<bool> _confirmDelete(Student student) async {
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
    return confirmed == true;
  }

  /// Moves [student] to the Trash and offers an Undo snackbar that brings them
  /// back.
  ///
  /// Nothing is removed from the database: the student keeps their picture,
  /// promotion record and achievements, and only disappears from the lists.
  /// Undo, or Restore on the Trash page, makes them visible again exactly as
  /// they were, with the same id and registry number.
  Future<void> _performDelete(Student student) async {
    if (!await _moveToTrash(student) || !mounted) return;
    _removeAndOfferUndo(student);
  }

  /// Moves [student] to the Trash in the database. Returns false, after telling
  /// the user, when that did not work.
  Future<bool> _moveToTrash(Student student) async {
    final id = student.id;
    if (id == null) return false;
    _localWrites++;
    try {
      await _storage.moveToTrash(id);
      return true;
    } catch (_) {
      _saveFailed();
      return false;
    }
  }

  /// Takes [student] off the list and offers the Undo snackbar. The card is
  /// removed by id, not by a position read before the database finished, so a
  /// list that changed in the meantime can never lose the wrong card.
  void _removeAndOfferUndo(Student student) {
    setState(() {
      _localWrites++;
      _students.removeWhere((s) => s.id == student.id);
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${student.name} moved to Trash'),
          // A snackbar with an action stays on screen until it is tapped
          // unless `persist` is switched off, so the Undo message would never
          // go away by itself. It now leaves after five seconds; tapping Undo
          // within that time still restores the student.
          persist: false,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _undoDelete(student),
          ),
        ),
      );
  }

  /// The ids of the students a swipe has already moved to the Trash in the
  /// database, kept until the card's `onDismissed` takes the card off the list.
  final Set<int> _swiped = {};

  /// Confirms and moves to the Trash before the card is allowed to slide away.
  /// When the database refuses, this returns false, the card springs back and
  /// the list stays exactly as it is; a card that was dismissed but is still in
  /// the list is what used to raise the framework's "dismissed Dismissible is
  /// still part of the tree" error.
  Future<bool> _confirmSwipeDelete(Student student) async {
    if (!await _confirmDelete(student)) return false;
    if (!await _moveToTrash(student)) return false;
    _swiped.add(student.id!);
    return true;
  }

  /// The card has slid away: drop it from the list and offer Undo.
  void _finishSwipeDelete(Student student) {
    if (_swiped.remove(student.id)) {
      _removeAndOfferUndo(student);
      return;
    }
    setState(() {
      _localWrites++;
      _students.removeWhere((s) => s.id == student.id);
    });
  }

  /// Takes the student back out of the Trash, then re-reads the registry so the
  /// list is exactly what is saved. Their picture, promotion record and
  /// achievements were never removed, so they are all back with them.
  Future<void> _undoDelete(Student student) async {
    final id = student.id;
    if (id == null) return;
    _localWrites++;
    try {
      await _storage.restoreFromTrash(id);
    } catch (_) {
      _saveFailed();
      return;
    }
    await _loadStudents();
  }

  /// Opens the Trash. Restoring a student there changes the registry, so the
  /// list is read again when the page is closed.
  Future<void> _openTrash() async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const TrashScreen()));
    if (!mounted) return;
    if (_seenRevision != StudentStorage.revision) await _loadStudents();
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
        BrandHeader(
          // The Trash button sits in the upper-right corner of the page.
          actions: [
            IconButton(
              tooltip: 'Trash',
              onPressed: _openTrash,
              icon: const Icon(Icons.delete_outline, color: Colors.white),
            ),
          ],
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
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
                      const SizedBox(height: 12),
                      // The search box sits at the bottom of the header block,
                      // beside the Add Student action, matching the
                      // Achievement page layout.
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
                        ),
                    ],
                  ),
                ),
              ),
              if (!_loading && results.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final student = results[index];
                      return Dismissible(
                        key: ValueKey(student.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) => _confirmSwipeDelete(student),
                        onDismissed: (_) => _finishSwipeDelete(student),
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
                      );
                    }, childCount: results.length),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Card for one student: the saved 1 x 1 picture (the initials until one is
/// uploaded) that opens larger when it is tapped, the name with the family name
/// first, the nickname and the school, and an Edit button in the top-right
/// corner. The whole card opens the student's details; the picture and the Edit
/// button take their own taps.
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
                // The picture opens larger on its own; this inner gesture
                // claims the tap, so it never also opens the details.
                GestureDetector(
                  onTap: () => _showPhoto(context),
                  child: StudentAvatar(
                    student: student,
                    size: 56,
                    borderRadius: 14,
                    initialsFontSize: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayStudentName(student.name),
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
                    ],
                  ),
                ),
                // Edit sits in the upper-right corner. Being a button, it takes
                // its own tap, so the card underneath is not opened as well.
                IconButton(
                  tooltip: 'Edit student',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, color: AppColors.black),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (student.schoolName.isNotEmpty) ...[
              const SizedBox(height: 14),
              _infoRow('School', student.schoolName),
            ],
          ],
        ),
      ),
    );
  }

  /// Shows the student's saved picture larger, centred in a dialog.
  ///
  /// The picture is the one on the student's own row ([Student.photoBytes]); a
  /// student who has none opens their initials at the same size, so the tap
  /// always does something. Tap outside, or the Close button, to dismiss it.
  void _showPhoto(BuildContext context) {
    final bytes = student.photoBytes;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close, color: AppColors.black),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 240,
                      height: 240,
                      child: bytes == null
                          ? StudentAvatar(
                              student: student,
                              size: 240,
                              borderRadius: 16,
                              initialsFontSize: 72,
                            )
                          : Image.memory(bytes, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    displayStudentName(student.name),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A gray label (`School`) with its value next to it.
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
