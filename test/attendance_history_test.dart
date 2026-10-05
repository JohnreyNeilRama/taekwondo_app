import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/attendance_storage.dart';
import 'package:tkd_app/services/student_storage.dart';

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

  test('a student with no check-ins has no history', () async {
    final saved = await students.insert(const Student(name: 'Ana Cruz'));

    final history = await attendance.loadHistory(saved.id!);

    expect(history.daysAttended, 0);
    expect(history.lastScanned, isNull);
    expect(history.records, isEmpty);
  });

  test('the history counts the days and reports the latest scan', () async {
    final ana = await students.insert(const Student(name: 'Ana Cruz'));
    final ben = await students.insert(const Student(name: 'Ben Reyes'));
    // Written out of order on purpose: the list is by day, not by write order.
    await attendance.checkIn(ana, now: DateTime(2026, 3, 4, 18, 5));
    await attendance.checkIn(ana, now: DateTime(2026, 3, 2, 9, 30));
    await attendance.checkIn(ana, now: DateTime(2026, 3, 3, 9, 45));
    await attendance.checkIn(ben, now: DateTime(2026, 3, 9, 9, 0));

    final history = await attendance.loadHistory(ana.id!);

    expect(history.daysAttended, 3);
    expect(history.lastScanned, DateTime(2026, 3, 4, 18, 5));
    expect([for (final record in history.records) record.day], [
      '2026-03-04',
      '2026-03-03',
      '2026-03-02',
    ]);
    // Somebody else's check-ins are never counted.
    expect((await attendance.loadHistory(ben.id!)).daysAttended, 1);
  });

  test('undoing a scan removes that day and the student can be scanned again',
      () async {
    final ana = await students.insert(const Student(name: 'Ana Cruz'));
    await attendance.checkIn(ana, now: DateTime(2026, 3, 2, 9, 30));
    await attendance.checkIn(ana, now: DateTime(2026, 3, 4, 18, 5));
    final mistaken = (await attendance.loadHistory(ana.id!)).records.first;
    final before = AttendanceStorage.revision;

    final removed = await attendance.undoCheckIn(ana.id!, mistaken.id);

    expect(removed, isTrue);
    expect(AttendanceStorage.revision, greaterThan(before));
    final history = await attendance.loadHistory(ana.id!);
    expect(history.daysAttended, 1);
    // The earlier day is the latest one again.
    expect(history.lastScanned, DateTime(2026, 3, 2, 9, 30));

    // The day is free again, so a correct scan is recorded, not "already here".
    final again = await attendance.checkIn(
      ana,
      now: DateTime(2026, 3, 4, 19, 0),
    );
    expect(again.status, CheckInStatus.recorded);
    expect((await attendance.loadHistory(ana.id!)).daysAttended, 2);
  });

  test('an undo only removes the right student\'s check-in', () async {
    final ana = await students.insert(const Student(name: 'Ana Cruz'));
    final ben = await students.insert(const Student(name: 'Ben Reyes'));
    await attendance.checkIn(ana, now: DateTime(2026, 3, 2, 9, 30));
    final record = (await attendance.loadHistory(ana.id!)).records.single;
    final before = AttendanceStorage.revision;

    // Asked for with the wrong student, or for a row that does not exist.
    expect(await attendance.undoCheckIn(ben.id!, record.id), isFalse);
    expect(await attendance.undoCheckIn(ana.id!, record.id + 100), isFalse);

    expect((await attendance.loadHistory(ana.id!)).daysAttended, 1);
    // Nothing changed, so nothing is told to refresh.
    expect(AttendanceStorage.revision, before);

    // Undoing the same scan twice removes it once.
    expect(await attendance.undoCheckIn(ana.id!, record.id), isTrue);
    expect(await attendance.undoCheckIn(ana.id!, record.id), isFalse);
  });
}
