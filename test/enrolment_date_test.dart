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
DateTime _at(int day, [int hour = 9, int minute = 0]) =>
    DateTime(2020, 3, day, hour, minute);

/// An enrolment time in the shape the storage layer writes: local-time ISO 8601.
String _enrolled(int day, [int hour = 8]) => _at(day, hour).toIso8601String();

/// Monday / Wednesday / Friday in March 2020.
const Set<int> _mwfMarch = {2, 4, 6, 9, 11, 13, 16, 18, 20, 23, 25, 27, 30};

Set<int> _missedFrom(int enrolledDay, {Set<int> present = const {}}) => {
      for (final day in _mwfMarch)
        if (day >= enrolledDay && !present.contains(day)) day,
    };

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

  /// One class, March 2020. Classes run Monday, Wednesday and Friday:
  /// 2, 4, 6, 9, 11, 13, 16, 18, 20, 23, 25, 27, 30.
  ///
  /// * Ben    enrolled Mar 1,  present on 2, 4, 6, 9
  /// * Ana    enrolled Mar 3,  present Mar 4
  /// * Cara   enrolled Mar 4,  never checked in
  /// * Eve    enrolled Mar 5,  never checked in
  /// * Fay    enrolled Mar 10, checked in Mar 4 (before her recorded date)
  /// * Dan    no enrolment date at all, present Mar 6
  Future<Map<String, Student>> seedClass() async {
    await ClassSchedule().save({
      ClassSchedule.monday,
      3,
      5,
    });
    final ben = await students.insert(
      Student(name: 'Ben Reyes', createdAt: _enrolled(1)),
    );
    final ana = await students.insert(
      Student(name: 'Ana Cruz', createdAt: _enrolled(3)),
    );
    final cara = await students.insert(
      Student(name: 'Cara Diaz', createdAt: _enrolled(4)),
    );
    final eve = await students.insert(
      Student(name: 'Eve Lim', createdAt: _enrolled(5)),
    );
    final fay = await students.insert(
      Student(name: 'Fay Go', createdAt: _enrolled(10)),
    );
    // Written straight into the table, so created_at keeps its empty default:
    // the way a row looks when nothing could be estimated for it.
    final db = await AppDatabase.instance.database;
    final danId = await db.insert('students', {
      'student_no': 'TKD-0099',
      'name': 'Dan Uy',
    });
    final dan = Student(id: danId, name: 'Dan Uy');

    for (final day in [2, 4, 6, 9]) {
      await attendance.checkIn(ben, now: _at(day, 9));
    }
    await attendance.checkIn(ana, now: _at(4, 9, 30));
    await attendance.checkIn(fay, now: _at(4, 10));
    await attendance.checkIn(dan, now: _at(6, 9, 45));

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
      await seedClass();

      final report = await attendance.loadReport(_at(4));

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
      expect(report.sessionHeld, isTrue);
      expect(report.scheduleSet, isTrue);
    });

    test('leaves out everyone who had not joined yet on an earlier day',
        () async {
      await seedClass();

      final report = await attendance.loadReport(_at(2));

      expect([for (final e in report.present) e.student.name], ['Ben Reyes']);
      // Only Dan (no date) could have missed it; Ana, Cara, Eve and Fay joined
      // after Mar 2.
      expect([for (final s in report.absent) s.name], ['Dan Uy']);
      expect(report.total, 2);
    });

    test('a class day with nobody scanned still lists everyone enrolled as absent',
        () async {
      await seedClass();

      // Wednesday 11 March: nobody was checked in, but it is a class day.
      final report = await attendance.loadReport(_at(11));

      expect(report.sessionHeld, isTrue);
      expect(report.present, isEmpty);
      expect([for (final s in report.absent) s.name], [
        'Ana Cruz',
        'Ben Reyes',
        'Cara Diaz',
        'Dan Uy',
        'Eve Lim',
        'Fay Go',
      ]);
    });

    test('a day off the schedule has no absent list, even with a make-up scan',
        () async {
      final s = await seedClass();
      await attendance.checkIn(s['ben']!, now: _at(5, 9));

      final report = await attendance.loadReport(_at(5));

      expect(report.sessionHeld, isFalse);
      expect([for (final e in report.present) e.student.name], ['Ben Reyes']);
      expect(report.absent, isEmpty);
    });

    test('does not guess absences until class days have been set', () async {
      await students.insert(Student(name: 'Ana Cruz', createdAt: _enrolled(1)));
      final ben = await students.insert(
        Student(name: 'Ben Reyes', createdAt: _enrolled(1)),
      );
      await attendance.checkIn(ben, now: _at(2, 9));

      final report = await attendance.loadReport(_at(2));

      expect(report.scheduleSet, isFalse);
      expect(report.sessionHeld, isFalse);
      expect([for (final e in report.present) e.student.name], ['Ben Reyes']);
      expect(report.absent, isEmpty);
    });
  });

  group("a student's calendar month", () {
    Future<StudentMonthAttendance> month(Student student) =>
        attendance.loadMonth(student.id!, DateTime(2020, 3));

    test('counts absences from the enrolment day, the day itself included',
        () async {
      final s = await seedClass();

      final ana = await month(s['ana']!);
      expect(ana.presentDays, {4});
      expect(ana.absentDays, _missedFrom(3, present: {4}));
      expect(ana.scheduleSet, isTrue);

      final cara = await month(s['cara']!);
      expect(cara.presentDays, isEmpty);
      expect(cara.absentDays, _missedFrom(4));

      final eve = await month(s['eve']!);
      expect(eve.absentDays, _missedFrom(5));

      final ben = await month(s['ben']!);
      expect(ben.presentDays, {2, 4, 6, 9});
      expect(ben.absentDays, _missedFrom(1, present: {2, 4, 6, 9}));
    });

    test('a student who joins after earlier classes is only absent from then on',
        () async {
      final s = await seedClass();

      final fay = await month(s['fay']!);
      expect(fay.presentDays, {4});
      expect(fay.absentDays, _missedFrom(10, present: {4}));
    });

    test('a student with no enrolment date falls back to the first check-in',
        () async {
      final s = await seedClass();

      final dan = await month(s['dan']!);
      expect(dan.presentDays, {6});
      // Counted from Mar 6, not from the beginning of time.
      expect(dan.absentDays, _missedFrom(6, present: {6}));
    });

    test('does not mark absences from other students being scanned', () async {
      final ana = await students.insert(
        Student(name: 'Ana Cruz', createdAt: _enrolled(1)),
      );
      final ben = await students.insert(
        Student(name: 'Ben Reyes', createdAt: _enrolled(1)),
      );
      await attendance.checkIn(ben, now: _at(2, 9));

      final monthAna = await month(ana);
      expect(monthAna.scheduleSet, isFalse);
      expect(monthAna.presentDays, isEmpty);
      expect(monthAna.absentDays, isEmpty);
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

  group('class days in a backup', () {
    test('carry the schedule and restore it onto an empty device', () async {
      await ClassSchedule().save({1, 3, 5});
      final file = await backup.exportBytes();

      expect(_decode(file)['classDays'], [1, 3, 5]);

      await _freshDatabase();
      await backup.importBytes(file);

      expect(await ClassSchedule().load(), {1, 3, 5});
    });

    test('never overwrite class days already set here', () async {
      await ClassSchedule().save({1, 3, 5});
      final file = await backup.exportBytes();

      await _freshDatabase();
      await ClassSchedule().save({2, 4});
      await backup.importBytes(file);

      expect(await ClassSchedule().load(), {2, 4});
    });
  });
}
