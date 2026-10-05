import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/attendance_storage.dart';
import 'package:tkd_app/services/student_qr.dart';
import 'package:tkd_app/services/student_storage.dart';
import 'package:tkd_app/services/student_uid.dart';

Future<int> _attendanceRows() async {
  final db = await AppDatabase.instance.database;
  final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM attendance');
  return rows.first['total'] as int;
}

void main() {
  final StudentStorage students = StudentStorage();
  final AttendanceStorage attendance = AttendanceStorage();

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

  test('the attendance table keeps one row per student per day', () async {
    final db = await AppDatabase.instance.database;
    final columns = await db.rawQuery('PRAGMA table_info(attendance)');
    expect([for (final column in columns) column['name']], [
      'id',
      'student_id',
      'attended_on',
      'checked_in_at',
    ]);

    final create = await db.rawQuery(
      "SELECT sql FROM sqlite_master WHERE name = 'attendance'",
    );
    expect(create.first['sql'] as String, contains('UNIQUE'));
  });

  test('a QR code carries the student uid and reads back to it', () {
    final uid = StudentUid.generate();
    final text = StudentQr.encode(uid);

    expect(StudentQr.decode(text), uid);
    expect(StudentQr.decode('  $text \n'), uid);

    // Anything that is not one of this app's codes is refused.
    expect(StudentQr.decode(uid), isNull);
    expect(StudentQr.decode('TKD:not-a-uid'), isNull);
    expect(StudentQr.decode('https://example.com'), isNull);
    expect(StudentQr.decode(''), isNull);
  });

  test('a new student has a uid, so a QR code can be made for them', () async {
    final saved = await students.insert(const Student(name: 'Nguyen Van A'));

    expect(isStudentUid(saved.uid), isTrue);
  });

  test('scanning records attendance once per day', () async {
    final saved = await students.insert(const Student(name: 'Nguyen Van A'));
    final code = StudentQr.encode(saved.uid);
    final morning = DateTime(2026, 10, 6, 9, 30);

    final first = await attendance.checkInScanned(code, now: morning);
    expect(first.status, CheckInStatus.recorded);
    expect(first.student?.name, 'Nguyen Van A');
    expect(first.checkedInAt, morning);

    // The same code again the same day writes nothing and reports the first
    // time.
    final again = await attendance.checkInScanned(
      code,
      now: DateTime(2026, 10, 6, 9, 45),
    );
    expect(again.status, CheckInStatus.alreadyPresent);
    expect(again.checkedInAt, morning);
    expect(await _attendanceRows(), 1);

    // The next day is a new check-in.
    final nextDay = await attendance.checkInScanned(
      code,
      now: DateTime(2026, 10, 7, 9, 30),
    );
    expect(nextDay.status, CheckInStatus.recorded);
    expect(await _attendanceRows(), 2);

    final day = await attendance.loadDay(morning);
    expect(day, hasLength(1));
    expect(day.single.student.name, 'Nguyen Van A');
    expect(day.single.checkedInAt, morning);
  });

  test('an unknown code, a foreign code and a student in the Trash are not '
      'checked in', () async {
    final saved = await students.insert(const Student(name: 'Nguyen Van A'));

    final stranger = StudentQr.encode(StudentUid.generate());
    expect(
      (await attendance.checkInScanned(stranger)).status,
      CheckInStatus.unknown,
    );
    expect(
      (await attendance.checkInScanned('hello')).status,
      CheckInStatus.unknown,
    );

    await students.moveToTrash(saved.id!);
    final trashed = await attendance.checkInScanned(
      StudentQr.encode(saved.uid),
    );
    expect(trashed.status, CheckInStatus.inTrash);
    expect(trashed.student?.name, 'Nguyen Van A');
    expect(await _attendanceRows(), 0);
  });

  test('a student number works when there is no code to scan', () async {
    final saved = await students.insert(const Student(name: 'Nguyen Van A'));
    expect(saved.studentNo, 'TKD-0001');

    final first = await attendance.checkInByStudentNo('1');
    expect(first.status, CheckInStatus.recorded);

    // Every spelling of the same number is the same student.
    for (final entered in ['TKD-0001', 'tkd-1', ' 0001 ']) {
      final again = await attendance.checkInByStudentNo(entered);
      expect(again.status, CheckInStatus.alreadyPresent, reason: entered);
    }

    for (final entered in ['', 'abc', '0', '99']) {
      final result = await attendance.checkInByStudentNo(entered);
      expect(result.status, CheckInStatus.unknown, reason: entered);
    }
    expect(await _attendanceRows(), 1);
  });

  test('the day list leaves out students in the Trash and keeps them when '
      'restored', () async {
    final saved = await students.insert(const Student(name: 'Nguyen Van A'));
    final moment = DateTime(2026, 10, 6, 18, 0);
    await attendance.checkIn(saved, now: moment);

    await students.moveToTrash(saved.id!);
    expect(await attendance.loadDay(moment), isEmpty);

    await students.restoreFromTrash(saved.id!);
    expect(await attendance.loadDay(moment), hasLength(1));
  });

  test('attendance leaves with a student who is deleted permanently', () async {
    final saved = await students.insert(const Student(name: 'Nguyen Van A'));
    await attendance.checkIn(saved);
    expect(await _attendanceRows(), 1);

    await students.moveToTrash(saved.id!);
    await students.deletePermanently(saved.id!);

    expect(await _attendanceRows(), 0);
  });
}
