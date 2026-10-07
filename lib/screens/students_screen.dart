import 'package:flutter/material.dart';

import '../models/student.dart';
import '../services/student_storage.dart';
import '../theme/app_dark.dart';
import '../widgets/registry_header.dart';
import '../widgets/student_list_card.dart';
import '../widgets/student_search_bar.dart';
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

/// How the student list is ordered. Family name A-Z is the default and what the
/// registry has always shown.
enum StudentSort {
  nameAsc('Name A\u2013Z'),
  nameDesc('Name Z\u2013A'),
  newest('Recently added'),
  oldest('Oldest first');

  const StudentSort(this.label);

  final String label;
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
  final ScrollController _scroll = ScrollController();
  final StudentStorage _storage = StudentStorage();
  final List<Student> _students = [];
  bool _loading = true;
  String _query = '';
  StudentSort _sort = StudentSort.nameAsc;

  /// True once the page has been scrolled far enough that the Add Student
  /// button in the section header is out of sight: the pinned search row then
  /// grows a compact "+" so adding a student is always one tap away.
  bool _compactAdd = false;
  static const double _compactAddAfter = 90;

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
    _scroll.addListener(_onScroll);
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
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final past = _scroll.hasClients && _scroll.offset > _compactAddAfter;
    if (past != _compactAdd) setState(() => _compactAdd = past);
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

  /// The students on screen: the search box's filter, in the chosen order
  /// (family name A-Z unless the sort button says otherwise). Building and
  /// sorting a fresh list on every read is what makes the order update by
  /// itself after an add or an edit; the stored [_students], and every TKD
  /// number, is left exactly as it is.
  List<Student> get _results {
    final q = _query.trim().toLowerCase();
    final list = q.isEmpty
        ? List<Student>.of(_students)
        : _students.where((s) => _matches(s, q)).toList();
    list.sort(switch (_sort) {
      StudentSort.nameAsc => _byFamilyName,
      StudentSort.nameDesc => (Student a, Student b) => _byFamilyName(b, a),
      StudentSort.newest => (Student a, Student b) =>
          (b.id ?? 0).compareTo(a.id ?? 0),
      StudentSort.oldest => (Student a, Student b) =>
          (a.id ?? 0).compareTo(b.id ?? 0),
    });
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
    _dismissUndoBar();
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
    _dismissUndoBar();
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
    _dismissUndoBar();
    final updated = await Navigator.of(context).push<Student>(
      MaterialPageRoute(builder: (_) => AddStudentScreen(initial: student)),
    );
    if (updated == null || !mounted) return;
    await _applyEdit(updated);
  }

  /// Opens a student's QR code, the one scanned to record attendance.
  void _showQr(Student student) {
    _dismissUndoBar();
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => StudentQrScreen(student: student)),
    );
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
        backgroundColor: AppDark.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppDark.border),
        ),
        title: const Text(
          'Delete student?',
          style: TextStyle(
            color: AppDark.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '${student.name} will be moved to Trash. '
          'You can restore them from there.',
          style: const TextStyle(color: AppDark.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppDark.icon),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppDark.crimson),
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

  /// The "Move to Trash" choice of a card's menu: confirms first, like every
  /// other way of deleting.
  Future<void> _deleteFromMenu(Student student) async {
    _dismissUndoBar();
    if (!await _confirmDelete(student) || !mounted) return;
    await _performDelete(student);
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

  /// The Undo message of the last deletion, while it is on screen.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _undoBar;

  /// Closes the Undo message, so the deletion stands. Called when the owner
  /// taps anywhere else on the screen or leaves for another page.
  void _dismissUndoBar() {
    final bar = _undoBar;
    if (bar == null) return;
    _undoBar = null;
    bar.close();
  }

  /// Takes [student] off the list and offers the Undo snackbar. The card is
  /// removed by id, not by a position read before the database finished, so a
  /// list that changed in the meantime can never lose the wrong card.
  void _removeAndOfferUndo(Student student) {
    setState(() {
      _localWrites++;
      _students.removeWhere((s) => s.id == student.id);
    });
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    // With an action, the message stays until the owner chooses: Undo brings
    // the student back, and tapping anywhere else on the screen closes it and
    // keeps the deletion (see the Listener in build).
    final bar = messenger.showSnackBar(
      SnackBar(
        content: Text('${student.name} moved to Trash'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _undoDelete(student),
        ),
      ),
    );
    _undoBar = bar;
    bar.closed.then((_) {
      if (identical(_undoBar, bar)) _undoBar = null;
    });
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
    _dismissUndoBar();
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const TrashScreen()));
    if (!mounted) return;
    if (_seenRevision != StudentStorage.revision) await _loadStudents();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  /// Lets the owner choose how the list is ordered.
  Future<void> _openSort() async {
    _dismissUndoBar();
    final picked = await showModalBottomSheet<StudentSort>(
      context: context,
      backgroundColor: AppDark.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Sort students',
                style: TextStyle(
                  color: AppDark.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final option in StudentSort.values)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text(
                  option.label,
                  style: TextStyle(
                    color: option == _sort
                        ? AppDark.crimson
                        : AppDark.textPrimary,
                    fontWeight: option == _sort
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                trailing: option == _sort
                    ? const Icon(Icons.check_rounded, color: AppDark.crimson)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _sort = picked);
  }

  /// "All Students" and the record count, with the Add Student button beside
  /// them when the width allows and underneath, full width, when it does not.
  Widget _sectionHeader(String countLabel) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= 360;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'All Students',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: AppDark.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              countLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: AppDark.textSecondary,
              ),
            ),
          ],
        );
        if (sideBySide) {
          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 12),
              _AddStudentButton(onPressed: _addStudent),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: 14),
            _AddStudentButton(onPressed: _addStudent, expand: true),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final hasQuery = _query.trim().isNotEmpty;
    final count = results.length;
    var countLabel = hasQuery
        ? '$count result${count == 1 ? '' : 's'} for "${_query.trim()}"'
        : '$count record${count == 1 ? '' : 's'}';
    if (_sort != StudentSort.nameAsc) {
      countLabel = '$countLabel \u00B7 ${_sort.label}';
    }

    return Listener(
      // Any tap on the screen (outside the Undo message itself) closes the
      // Undo message of a deletion, so the deletion stands.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _dismissUndoBar(),
      child: Column(
        children: [
          RegistryHeader(
            // The Trash button sits in the upper-right corner of the page.
            actions: [
              HeaderIconButton(
                icon: Icons.delete_outline,
                tooltip: 'Trash',
                onPressed: _openTrash,
              ),
            ],
          ),
          Expanded(
            // The page is a sheet with rounded top corners laid over the
            // header; the colour behind is what shows in the two cut corners.
            child: ColoredBox(
              color: AppDark.headerBottom,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: ColoredBox(
                  color: AppDark.background,
                  // On a tablet or a computer the list keeps a phone-like
                  // reading width instead of stretching edge to edge.
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: _buildScroll(results, hasQuery, countLabel),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScroll(
    List<Student> results,
    bool hasQuery,
    String countLabel,
  ) {
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: _sectionHeader(countLabel),
          ),
        ),
        // The search card stays at the top while the list scrolls under it, so
        // a student can be looked up from anywhere in a long registry.
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedSearchDelegate(
            search: StudentSearchBar(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              hasQuery: hasQuery,
              onClear: _clearSearch,
              onSort: _openSort,
              sortActive: _sort != StudentSort.nameAsc,
            ),
            showAdd: _compactAdd,
            onAdd: _addStudent,
          ),
        ),
        if (_loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: AppDark.crimson),
              ),
            ),
          )
        else if (results.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: _EmptyState(
                searching: hasQuery,
                onAdd: _addStudent,
                onClearSearch: _clearSearch,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final student = results[index];
                return Dismissible(
                  key: ValueKey(student.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => _confirmSwipeDelete(student),
                  onDismissed: (_) => _finishSwipeDelete(student),
                  background: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      decoration: BoxDecoration(
                        gradient: AppDark.crimsonGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: StudentListCard(
                      student: student,
                      title: displayStudentName(student.name),
                      onView: () => _openStudent(student),
                      onEdit: () => _editStudent(student),
                      onShowQr: () => _showQr(student),
                      onTrash: () => _deleteFromMenu(student),
                    ),
                  ),
                );
              }, childCount: results.length),
            ),
          ),
      ],
    );
  }
}

/// Keeps the search card (and the compact "+") pinned under the section header.
class _PinnedSearchDelegate extends SliverPersistentHeaderDelegate {
  _PinnedSearchDelegate({
    required this.search,
    required this.showAdd,
    required this.onAdd,
  });

  final Widget search;
  final bool showAdd;
  final VoidCallback onAdd;

  /// 52 for the card plus 10 above and below it.
  static const double extent = 72;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppDark.background,
        // A hairline appears once cards are sliding underneath.
        border: Border(
          bottom: BorderSide(
            color: overlapsContent ? AppDark.border : Colors.transparent,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: search),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: showAdd
                ? Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: _CompactAddButton(onPressed: onAdd),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedSearchDelegate oldDelegate) => true;
}

/// The main action: crimson, with a white plus, rounded corners, a soft red
/// glow and a ripple. [expand] makes it fill the width, for narrow phones.
class _AddStudentButton extends StatelessWidget {
  const _AddStudentButton({required this.onPressed, this.expand = false});

  final VoidCallback onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppDark.crimsonGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppDark.crimsonGlow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Add Student',
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The icon-only "+" that joins the pinned search row once the section header's
/// Add Student button has scrolled out of sight.
class _CompactAddButton extends StatelessWidget {
  const _CompactAddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Add student',
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppDark.crimsonGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppDark.crimsonGlow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: const SizedBox(
              width: 52,
              height: StudentSearchBar.height,
              child: Icon(Icons.add, color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the list shows when there is nothing to list: either the registry is
/// empty (with a way to add the first student) or the search matched nobody
/// (with a way to clear it).
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.searching,
    required this.onAdd,
    required this.onClearSearch,
  });

  final bool searching;
  final VoidCallback onAdd;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: BoxDecoration(
        color: AppDark.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDark.border),
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppDark.surfaceHigh,
              shape: BoxShape.circle,
              border: Border.all(color: AppDark.border),
            ),
            child: Icon(
              searching ? Icons.search_off_rounded : Icons.groups_outlined,
              size: 38,
              color: AppDark.rose,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No student records found.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppDark.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            searching
                ? 'No student matches that search. Try a name, nickname, '
                      'school or contact number.'
                : 'Add a student to start the registry.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppDark.textSecondary,
            ),
          ),
          const SizedBox(height: 22),
          if (searching)
            OutlinedButton(
              onPressed: onClearSearch,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppDark.textPrimary,
                side: const BorderSide(color: AppDark.border),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Clear search'),
            )
          else
            _AddStudentButton(onPressed: onAdd, expand: true),
        ],
      ),
    );
  }
}
