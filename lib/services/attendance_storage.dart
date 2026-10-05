import '../models/student.dart';
import 'app_database.dart';
import 'student_qr.dart';

/// What happened when somebody was checked in.
enum CheckInStatus {
  /// Attendance was written for today.
  recorded,

  /// The student was already checked in today; nothing was written again.
  alreadyPresent,

  /// The code belongs to a student who is in the Trash.
  inTrash,

  /// The code (or number) does not match any student in this registry.
  unknown,
}

/// The answer to one check-in, with the student it was about when there is one.
class CheckInResult {
  const CheckInResult(this.status, {this.student, this.checkedInAt});

  final CheckInStatus status;

  /// The student the code belongs to. Null only for [CheckInStatus.unknown].
  final Student? student;

  /// When the student was checked in: just now for [CheckInStatus.recorded],
  /// the earlier time for [CheckInStatus.alreadyPresent].
  final DateTime? checkedInAt;
}

/// One line of a day's attendance list.
class AttendanceEntry {
  const AttendanceEntry({required this.student, required this.checkedInAt});

  /// The student, carrying the compact picture the avatars draw.
  final Student student;

  final DateTime checkedInAt;
}

/// A whole day's attendance: who was checked in and who was not.
class AttendanceReport {
  const AttendanceReport({
    required this.day,
    required this.present,
    required this.absent,
  });

  /// The day the report is about.
  final DateTime day;

  /// Everyone checked in on [day], the earliest check-in first.
  final List<AttendanceEntry> present;

  /// Every student in the registry (not in the Trash) with no check-in on
  /// [day], in name order.
  final List<Student> absent;

  /// How many students the report covers.
  int get total => present.length + absent.length;

  /// Whether anybody was checked in. A day with no check-in at all is read as
  /// a day without class, so [absent] is not meaningful for it.
  bool get sessionHeld => present.isNotEmpty;
}

/// One saved check-in, as listed on a student's own page.
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.day,
    required this.checkedInAt,
  });

  /// Primary key of the `attendance` row; what an undo removes.
  final int id;

  /// The local day, as the `yyyy-mm-dd` text stored in `attended_on`.
  final String day;

  /// When the check-in was recorded.
  final DateTime checkedInAt;
}

/// Everything one student has been checked in for, newest day first.
class AttendanceHistory {
  const AttendanceHistory({required this.records});

  final List<AttendanceRecord> records;

  /// How many different days the student was checked in. A student has at most
  /// one check-in per day, so this is simply the number of records.
  int get daysAttended => records.length;

  /// The moment of the latest check-in, or null when there is none.
  DateTime? get lastScanned => records.isEmpty ? null : records.first.checkedInAt;
}

/// Reads and writes the `attendance` table: one row per student per day.
///
/// A row points at `students.id`, like the promotion and achievement records,
/// so renaming or renumbering a student never separates them from their
/// attendance. The table's UNIQUE (student_id, attended_on) rule is what keeps
/// a second scan on the same day from counting twice, whatever the screen does.
class AttendanceStorage {
  static const String _table = 'attendance';

  /// Bumped by every check-in, so a page that shows attendance can tell whether
  /// anything changed since it last read.
  static int revision = 0;

  /// The student columns a check-in needs: enough to find, name and draw them.
  static const List<String> _studentColumns = [
    'id',
    'uid',
    'student_no',
    'name',
    'nickname',
    'photo_base64',
    'deleted_at',
  ];

  /// The day [moment] falls on, as the `yyyy-mm-dd` text stored in
  /// `attended_on`. Local time: "today" means the owner's today.
  static String dayKey(DateTime moment) {
    final year = moment.year.toString().padLeft(4, '0');
    final month = moment.month.toString().padLeft(2, '0');
    final day = moment.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Checks in the student whose QR code text is [scanned].
  ///
  /// [now] is only for tests; the screens leave it out.
  Future<CheckInResult> checkInScanned(String scanned, {DateTime? now}) async {
    final uid = StudentQr.decode(scanned);
    if (uid == null) return const CheckInResult(CheckInStatus.unknown);
    return _checkInWhere('uid = ?', uid, now);
  }

  /// Checks in a student typed by registry number: `TKD-0012`, `tkd-12`, `12`
  /// and `0012` all mean the same student. This is the way in when the camera
  /// is not available (a computer) or a student forgot their code.
  Future<CheckInResult> checkInByStudentNo(
    String entered, {
    DateTime? now,
  }) async {
    final match = RegExp(
      r'^(?:TKD-?)?(\d+)$',
    ).firstMatch(entered.trim().toUpperCase());
    final number = match == null ? null : int.tryParse(match.group(1)!);
    if (number == null || number < 1) {
      return const CheckInResult(CheckInStatus.unknown);
    }
    final studentNo = 'TKD-${number.toString().padLeft(4, '0')}';
    return _checkInWhere('student_no = ?', studentNo, now);
  }

  /// Finds the one student matching [where] / [value] and checks them in.
  /// [where] is always one of the fixed strings above; the value is bound as a
  /// parameter.
  Future<CheckInResult> _checkInWhere(
    String where,
    String value,
    DateTime? now,
  ) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'students',
      columns: _studentColumns,
      where: where,
      whereArgs: [value],
      limit: 1,
    );
    if (rows.isEmpty) return const CheckInResult(CheckInStatus.unknown);

    final row = rows.first;
    final student = Student.fromMap(row);
    final deletedAt = row['deleted_at'] as String? ?? '';
    if (deletedAt.isNotEmpty) {
      return CheckInResult(CheckInStatus.inTrash, student: student);
    }
    return checkIn(student, now: now);
  }

  /// Records [student] as present on the day of [now] (today by default).
  ///
  /// The look-up and the insert share one transaction, so two quick scans of
  /// the same code can never write two rows: the second one finds the first and
  /// answers [CheckInStatus.alreadyPresent] with the original time.
  Future<CheckInResult> checkIn(Student student, {DateTime? now}) async {
    final id = student.id;
    if (id == null) {
      throw ArgumentError('A student without an id cannot be checked in.');
    }
    final moment = now ?? DateTime.now();
    final day = dayKey(moment);
    final db = await AppDatabase.instance.database;
    return db.transaction((txn) async {
      final existing = await txn.query(
        _table,
        columns: ['checked_in_at'],
        where: 'student_id = ? AND attended_on = ?',
        whereArgs: [id, day],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return CheckInResult(
          CheckInStatus.alreadyPresent,
          student: student,
          checkedInAt: DateTime.tryParse(
            existing.first['checked_in_at'] as String? ?? '',
          ),
        );
      }
      await txn.insert(_table, {
        'student_id': id,
        'attended_on': day,
        'checked_in_at': moment.toIso8601String(),
      });
      revision++;
      return CheckInResult(
        CheckInStatus.recorded,
        student: student,
        checkedInAt: moment,
      );
    });
  }

  /// Every check-in of one student, the latest day first. Used by the student
  /// page for "days attended", "last scanned" and the undo list.
  Future<AttendanceHistory> loadHistory(int studentId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      _table,
      columns: ['id', 'attended_on', 'checked_in_at'],
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'attended_on DESC, id DESC',
    );
    return AttendanceHistory(
      records: [
        for (final row in rows)
          () {
            final day = row['attended_on'] as String? ?? '';
            return AttendanceRecord(
              id: row['id'] as int,
              day: day,
              checkedInAt:
                  DateTime.tryParse(row['checked_in_at'] as String? ?? '') ??
                  DateTime.tryParse(day) ??
                  DateTime.fromMillisecondsSinceEpoch(0),
            );
          }(),
      ],
    );
  }

  /// Removes one check-in, the undo for a mistaken scan. [studentId] has to
  /// match the row too, so a stale list can never remove somebody else's day.
  ///
  /// Returns whether a row was removed. Afterwards the student can be scanned
  /// again for that day.
  Future<bool> undoCheckIn(int studentId, int recordId) async {
    final db = await AppDatabase.instance.database;
    final removed = await db.delete(
      _table,
      where: 'id = ? AND student_id = ?',
      whereArgs: [recordId, studentId],
    );
    if (removed == 0) return false;
    revision++;
    return true;
  }

  /// Who was present and who was absent on the day of [day].
  ///
  /// One query: every student who is not in the Trash, joined to their check-in
  /// for that day when there is one. A student with a check-in is present, a
  /// student without one is absent.
  Future<AttendanceReport> loadReport(DateTime day) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '''
SELECT s.id, s.uid, s.student_no, s.name, s.nickname, s.photo_base64,
       a.checked_in_at
FROM students s
LEFT JOIN attendance a
  ON a.student_id = s.id AND a.attended_on = ?
WHERE s.deleted_at = ''
ORDER BY s.name COLLATE NOCASE, s.id
''',
      [dayKey(day)],
    );

    final present = <AttendanceEntry>[];
    final absent = <Student>[];
    for (final row in rows) {
      final student = Student.fromMap(row);
      final checkedIn = row['checked_in_at'] as String?;
      if (checkedIn == null) {
        absent.add(student);
      } else {
        present.add(
          AttendanceEntry(
            student: student,
            checkedInAt: DateTime.tryParse(checkedIn) ?? day,
          ),
        );
      }
    }
    present.sort((a, b) => a.checkedInAt.compareTo(b.checkedInAt));
    return AttendanceReport(day: day, present: present, absent: absent);
  }

  /// Everyone checked in on the day of [day], the latest first. Students who
  /// are in the Trash are left out: they have left every list.
  Future<List<AttendanceEntry>> loadDay(DateTime day) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '''
SELECT s.id, s.uid, s.student_no, s.name, s.nickname, s.photo_base64,
       a.checked_in_at
FROM attendance a
JOIN students s ON s.id = a.student_id
WHERE a.attended_on = ? AND s.deleted_at = ''
ORDER BY a.checked_in_at DESC, a.id DESC
''',
      [dayKey(day)],
    );
    return [
      for (final row in rows)
        AttendanceEntry(
          student: Student.fromMap(row),
          checkedInAt:
              DateTime.tryParse(row['checked_in_at'] as String? ?? '') ?? day,
        ),
    ];
  }
}
