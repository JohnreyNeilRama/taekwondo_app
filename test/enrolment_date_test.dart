import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/attendance_storage.dart';
import 'package:tkd_app/services/class_schedule.dart';
import 'package:tkd_app/services/student_storage.dart';

/// January 2020 is far in the past, so "before today" never interferes. Its
/// Mondays are the 6th, 13th, 20th and 27th.
final DateTime _month = DateTime(2020, 1);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.debugReset();
    AppDatabase.debugOverridePath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await AppDatabase.debugReset();
  });

  final students = StudentStorage();
  final attendance = AttendanceStorage();

  /// Saves a student; [enrolled] overwrites the stamped enrolment time, the
  /// way an older registry or a hand-corrected date would look.
  Future<Student> addStudent(String name, {String? enrolled}) async {
    final saved = await students.insert(Student(name: name));
    if (enrolled != null) {
      final db = await AppDatabase.instance.database;
      await db.update(
        'students',
        {'created_at': enrolled},
        where: 'id = ?',
        whereArgs: [saved.id],
      );
    }
    return saved;
  }

  Future<String> storedEnrolment(int id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'students',
      columns: ['created_at'],
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.first['created_at'] as String? ?? '';
  }

  test('a new student is stamped with the time they were enrolled', () async {
    final before = DateTime.now();
    final saved = await addStudent('Ana');
    final after = DateTime.now();

    expect(saved.createdAt, isNotEmpty);
    final stamped = DateTime.parse(saved.createdAt);
    expect(stamped.isBefore(before.subtract(const Duration(seconds: 1))), false);
    expect(stamped.isAfter(after.add(const Duration(seconds: 1))), false);
    expect(await storedEnrolment(saved.id!), saved.createdAt);
  });

  test('an edit never changes or blanks the enrolment date', () async {
    final saved = await addStudent('Ana', enrolled: '2020-01-10T09:00:00.000');

    await students.update(Student(id: saved.id, name: 'Ana Renamed'));

    expect(await storedEnrolment(saved.id!), '2020-01-10T09:00:00.000');
  });

  test('the calendar counts absences only from the enrolment day', () async {
    await ClassSchedule().save({ClassSchedule.monday});
    final ana = await addStudent('Ana', enrolled: '2020-01-10T09:00:00.000');
    await attendance.checkIn(ana, now: DateTime(2020, 1, 20, 17));

    final result = await attendance.loadMonth(ana.id!, _month);

    expect(result.presentDays, {20});
    // The 6th was before Ana joined, so it is not an absence.
    expect(result.absentDays, {13, 27});
  });

  test('a student with no enrolment date counts from their first check-in',
      () async {
    await ClassSchedule().save({ClassSchedule.monday});
    final ben = await addStudent('Ben', enrolled: '');
    await attendance.checkIn(ben, now: DateTime(2020, 1, 13, 17));

    final result = await attendance.loadMonth(ben.id!, _month);

    expect(result.presentDays, {13});
    expect(result.absentDays, {20, 27});
  });

  test('the report leaves out a student who joined after the day', () async {
    await ClassSchedule().save({ClassSchedule.monday});
    await addStudent('Ana', enrolled: '2020-01-10T09:00:00.000');
    final ben = await addStudent('Ben', enrolled: '');
    await addStudent('Cara', enrolled: '2020-01-15T10:00:00.000');
    await attendance.checkIn(ben, now: DateTime(2020, 1, 13, 17));

    final report = await attendance.loadReport(DateTime(2020, 1, 13));

    expect([for (final e in report.present) e.student.name], ['Ben']);
    // Ana was enrolled by the 13th and missed it; Cara joined two days later.
    expect([for (final s in report.absent) s.name], ['Ana']);
    expect(report.total, 2);
  });
}
