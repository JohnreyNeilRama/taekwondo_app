import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/attendance_storage.dart';
import 'package:tkd_app/services/backup_service.dart';
import 'package:tkd_app/services/class_schedule.dart';
import 'package:tkd_app/services/student_storage.dart';

/// A moment in March 2020: far enough in the past that every day of the month
/// is before "today", so the "not today" rule never changes an answer.
///
/// March 2020 has its Mondays on the 2nd, 9th, 16th, 23rd and 30th, which is
/// what the class schedule below is built around.
DateTime _at(int day, [int hour = 9, int minute = 0]) =>
    DateTime(2020, 3, day, hour, minute);

/// An enrolment time in the shape the storage layer writes: local-time ISO 8601.
String _enrolled(int day, [int hour = 8]) => _at(day, hour).toIso8601String();

Future<void> _freshDatabase() async {
  await AppDatabase.debugReset();
  AppDatabase.debugOverridePath = inMemoryDatabasePath;
}

Map<String, Object?> _decode(Uint8List bytes) =>
    Map<String, Object?>.from(jsonDecode(utf8.decode(bytes)) as Map);

Uint8List _encode(Map<String, Object?> document) =>
    Uint8List.fromList(utf8.encode(jsonEncode(document)));

void main() {
  final StudentStorage students = StudentStorage();
  final AttendanceStorage attendance = AttendanceStorage();
  final BackupService backup = BackupService();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(_freshDatabase);

  tearDown(() async {
    await AppDatabase.debugReset();
  });

  /// One club, March 2020. Classes run on Mondays: the 2nd, 9th, 16th, 23rd and
  /// 30th. Absences are counted against that schedule, from each student's own
  /// enrolment day.
  ///
  /// * Ben    enrolled Mar 1,  present every Monday
  /// * Ana    enrolled Mar 10, present Mar 16 only
  /// * Cara   enrolled Mar 16, never checked in (joined on a class day)
  /// * Eve    enrolled Mar 17, never checked in
  /// * Fay    enrolled Mar 31, checked in Mar 16 (before her recorded date)
  /// * Dan    no enrolment date at all, present Mar 23 only
  Future<Map<String, Student>> seedClub() async {
    await ClassSchedule().save({ClassSchedule.monday});

    final ben = await students.insert(
      Student(name: 'Ben Reyes', createdAt: _enrolled(1)),
    );
    final ana = await students.insert(
      Student(name: 'Ana Cruz', createdAt: _enrolled(10)),
    );
    final cara = await students.insert(
      Student(name: 'Cara Diaz', createdAt: _enrolled(16)),
    );
    final eve = await students.insert(
      Student(name: 'Eve Lim', createdAt: _enrolled(17)),
    );
    final fay = await students.insert(
      Student(name: 'Fay Go', createdAt: _enrolled(31)),
    );
    // Written straight into the table, so created_at keeps its empty default:
    // the way a row looks when nothing could be estimated for it.
    final db = await AppDatabase.instance.database;
    final danId = await db.insert('students', {
      'student_no': 'TKD-0099',
      'name': 'Dan Uy',
    });
    final dan = Student(id: danId, name: 'Dan Uy');

    for (final day in [2, 9, 16, 23, 30]) {
      await attendance.checkIn(ben, now: _at(day, 9));
    }
    await attendance.checkIn(ana, now: _at(16, 9, 30));
    await attendance.checkIn(fay, now: _at(16, 10));
    await attendance.checkIn(dan, now: _at(23, 9, 45));

    return {
      'ben': ben,
      'ana': ana,
      'cara': cara,
      'eve': eve,
      'fay': fay,
      'dan': dan,
    };
  }

  group('stamping', () {
    test('a new student is stamped once and an edit never changes it', () async {
      final before = DateTime.now();
      final saved = await students.insert(const Student(name: 'Ana Cruz'));

      expect(saved.createdAt, isNotEmpty);
      final stamped = DateTime.parse(saved.createdAt);
      expect(
        stamped.isBefore(before.subtract(const Duration(seconds: 1))),
        isFalse,
      );
      expect(
        stamped.isAfter(DateTime.now().add(const Duration(seconds: 1))),
        isFalse,
      );

      // A form that carries another date, and one that carries none at all:
      // neither can change or blank the stored value.
      await students.update(
        Student(id: saved.id, name: 'Ana Santos', createdAt: _enrolled(1)),
      );
      await students.update(Student(id: saved.id, name: 'Ana Santos'));

      expect((await students.loadStudents()).single.createdAt, saved.createdAt);
    });

    test('a record that already carries an enrolment time keeps it', () async {
      final saved = await students.insert(
        Student(name: 'Ana Cruz', createdAt: _enrolled(3)),
      );

      expect(saved.createdAt, _enrolled(3));
      expect((await students.loadStudents()).single.createdAt, _enrolled(3));
    });
  });

  group('the attendance report', () {
    test('counts a student absent only from the day they were enrolled',
        () async {
      await seedClub();

      final report = await attendance.loadReport(_at(16));

      expect(report.sessionHeld, isTrue);
      // Present, earliest check-in first. Fay is here although her recorded
      // enrolment is later: a check-in always counts.
      expect([for (final e in report.present) e.student.name], [
        'Ben Reyes',
        'Ana Cruz',
        'Fay Go',
      ]);
      // Cara joined that very day, so she can be absent. Dan has no date and
      // is treated as enrolled. Eve joined the next day: in neither list.
      expect([for (final s in report.absent) s.name], ['Cara Diaz', 'Dan Uy']);
      expect(report.total, 5);
    });

    test('leaves out everyone who had not joined yet on an earlier day',
        () async {
      await seedClub();

      final report = await attendance.loadReport(_at(9));

      expect(report.sessionHeld, isTrue);
      expect([for (final e in report.present) e.student.name], ['Ben Reyes']);
      // Only Dan (no date) could have missed it; Ana, Cara, Eve and Fay joined
      // after Mar 9.
      expect([for (final s in report.absent) s.name], ['Dan Uy']);
      expect(report.total, 2);
    });
  });

  group("a student's calendar month", () {
    Future<StudentMonthAttendance> month(Student student) =>
        attendance.loadMonth(student.id!, DateTime(2020, 3));

    test('counts absences from the enrolment day, the day itself included',
        () async {
      final s = await seedClub();

      final ana = await month(s['ana']!);
      expect(ana.presentDays, {16});
      // Mar 2 and 9 were before she joined; Mar 23 and 30 she missed.
      expect(ana.absentDays, {23, 30});

      final cara = await month(s['cara']!);
      expect(cara.presentDays, isEmpty);
      // Mar 16 is the day she joined, so it counts.
      expect(cara.absentDays, {16, 23, 30});

      final eve = await month(s['eve']!);
      expect(eve.absentDays, {23, 30});

      final ben = await month(s['ben']!);
      expect(ben.presentDays, {2, 9, 16, 23, 30});
      expect(ben.absentDays, isEmpty);
    });

    test('a student who joins after the last class has no absences yet',
        () async {
      final s = await seedClub();

      final fay = await month(s['fay']!);
      expect(fay.presentDays, {16});
      expect(fay.absentDays, isEmpty);
    });

    test('a student with no enrolment date falls back to the first check-in',
        () async {
      final s = await seedClub();

      final dan = await month(s['dan']!);
      expect(dan.presentDays, {23});
      // Counted from Mar 23, not from the beginning of time.
      expect(dan.absentDays, {30});
    });
  });

  group('backups', () {
    test('carry the enrolment time and restore it', () async {
      await students.insert(Student(name: 'Ana Cruz', createdAt: _enrolled(3)));
      final file = await backup.exportBytes();

      final rows = _decode(file)['students'] as List;
      expect((rows.single as Map)['created_at'], _enrolled(3));

      await _freshDatabase();
      await backup.importBytes(file);

      expect((await students.loadStudents()).single.createdAt, _enrolled(3));
    });

    test('made before enrolment dates existed get an estimated date', () async {
      final ana = await students.insert(
        Student(name: 'Ana Cruz', createdAt: _enrolled(3)),
      );
      await students.insert(Student(name: 'Ben Reyes', createdAt: _enrolled(3)));
      await attendance.checkIn(ana, now: _at(4, 9));
      final old = _decode(await backup.exportBytes());
      for (final row in old['students'] as List) {
        (row as Map).remove('created_at');
      }

      await _freshDatabase();
      final before = DateTime.now();
      await backup.importBytes(_encode(old));

      final byName = {
        for (final s in await students.loadStudents()) s.name: s.createdAt,
      };
      // Ana: the day of her first check-in, the one just imported included.
      expect(byName['Ana Cruz'], '2020-03-04T00:00:00.000');
      // Ben never checked in, so he is counted from the import on.
      final ben = DateTime.tryParse(byName['Ben Reyes'] ?? '');
      expect(ben, isNotNull);
      expect(
        ben!.isBefore(before.subtract(const Duration(seconds: 1))),
        isFalse,
      );
    });

    test('never change the enrolment date of a student already here', () async {
      final ana = await students.insert(
        Student(name: 'Ana Cruz', createdAt: _enrolled(3)),
      );
      final file = await backup.exportBytes();

      // The same student, matched by identity, now with a different date on
      // this device: an import only ever adds, so the local one stays.
      final db = await AppDatabase.instance.database;
      await db.update(
        'students',
        {'created_at': _enrolled(8)},
        where: 'id = ?',
        whereArgs: [ana.id],
      );
      final result = await backup.importBytes(file);

      expect(result.matchedStudents, 1);
      expect((await students.loadStudents()).single.createdAt, _enrolled(8));
    });
  });
}
