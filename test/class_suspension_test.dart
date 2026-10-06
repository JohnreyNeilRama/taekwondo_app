import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/attendance_storage.dart';
import 'package:tkd_app/services/backup_service.dart';
import 'package:tkd_app/services/class_schedule.dart';
import 'package:tkd_app/services/student_qr.dart';
import 'package:tkd_app/services/student_storage.dart';

/// March 2020 is the month used throughout: it is long past, so every class day
/// in it is a finished one, and its Mondays are the 2nd, 9th, 16th, 23rd and
/// 30th.
const int _monday = DateTime.monday;

Future<int> _attendanceRows() async {
  final db = await AppDatabase.instance.database;
  final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM attendance');
  return rows.first['total'] as int;
}

Future<void> _freshDatabase() async {
  await AppDatabase.debugReset();
  AppDatabase.debugOverridePath = inMemoryDatabasePath;
}

void main() {
  final StudentStorage students = StudentStorage();
  final AttendanceStorage attendance = AttendanceStorage();
  final ClassSchedule schedule = ClassSchedule();
  final BackupService backup = BackupService();

  /// A student enrolled before the month starts, so every Monday in it counts.
  Future<Student> enrol(String name) => students.insert(
    Student(name: name, createdAt: DateTime(2020, 3, 1).toIso8601String()),
  );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(_freshDatabase);

  tearDown(() async {
    await AppDatabase.debugReset();
  });

  group('the schedule', () {
    test('a cancelled date overrides the weekday schedule', () {
      final cancelledMonday = DateTime(2020, 3, 16);
      final cancelled = {ClassSchedule.dayKey(cancelledMonday)};

      expect(ClassSchedule.dayKey(cancelledMonday), '2020-03-16');
      expect(ClassSchedule.isClassDay({_monday}, cancelledMonday), isTrue);
      expect(
        ClassSchedule.isClassDay(
          {_monday},
          cancelledMonday,
          cancelled: cancelled,
        ),
        isFalse,
      );
      // The Monday after is untouched.
      expect(
        ClassSchedule.isClassDay(
          {_monday},
          DateTime(2020, 3, 23),
          cancelled: cancelled,
        ),
        isTrue,
      );
    });

    test('the days of a month leave the cancelled ones out', () {
      final days = ClassSchedule.classDaysOfMonth(
        {_monday},
        DateTime(2020, 3),
        cancelled: {'2020-03-16'},
      ).map((date) => date.day).toList();

      expect(days, [2, 9, 23, 30]);
      expect(
        ClassSchedule.cancelledDaysOfMonth({
          '2020-03-16',
          '2020-03-04',
          '2020-04-06',
        }, DateTime(2020, 3)),
        {4, 16},
      );
    });

    test('stored cancelled dates keep only real calendar days', () {
      expect(
        ClassSchedule.parseDates('2020-03-16, nope,2020-3-1,2020-04-06'),
        {'2020-03-16', '2020-04-06'},
      );
      expect(ClassSchedule.parseDates(null), isEmpty);
      expect(ClassSchedule.parseDates(''), isEmpty);
      expect(ClassSchedule.fromDateList('2020-03-16'), isNull);
      expect(ClassSchedule.fromDateList(['2020-03-16', 'x']), {'2020-03-16'});
    });

    test('any date of any month can be cancelled and put back', () async {
      expect(await schedule.loadCancelled(), isEmpty);
      final before = ClassSchedule.revision;

      await schedule.setCancelled(DateTime(2020, 3, 16), true);
      await schedule.setCancelled(DateTime(2027, 12, 25), true);
      expect(await schedule.loadCancelled(), {'2020-03-16', '2027-12-25'});
      expect(ClassSchedule.revision, greaterThan(before));

      await schedule.setCancelled(DateTime(2020, 3, 16), false);
      expect(await schedule.loadCancelled(), {'2027-12-25'});

      // Removing it a second time is harmless.
      await schedule.setCancelled(DateTime(2020, 3, 16), false);
      expect(await schedule.loadCancelled(), {'2027-12-25'});
    });

    test('cancelling a date never changes the weekday schedule', () async {
      await schedule.save({1, 3});
      await schedule.setCancelled(DateTime(2020, 3, 16), true);

      expect(await schedule.load(), {1, 3});
      await schedule.save({1, 3, 5});
      expect(await schedule.loadCancelled(), {'2020-03-16'});
    });
  });

  group('the attendance report', () {
    test('a cancelled class day is neither present nor absent', () async {
      final ana = await enrol('Ana Cruz');
      await enrol('Ben Reyes');
      await schedule.save({_monday});
      final monday = DateTime(2020, 3, 16);
      await attendance.checkIn(ana, now: DateTime(2020, 3, 16, 9));

      var report = await attendance.loadReport(monday);
      expect(report.sessionHeld, isTrue);
      expect(report.trainingCancelled, isFalse);
      expect([for (final e in report.present) e.student.name], ['Ana Cruz']);
      expect([for (final s in report.absent) s.name], ['Ben Reyes']);

      await schedule.setCancelled(monday, true);
      report = await attendance.loadReport(monday);
      expect(report.trainingCancelled, isTrue);
      expect(report.sessionHeld, isFalse);
      expect(report.present, isEmpty);
      expect(report.absent, isEmpty);
      expect(report.total, 0);

      // The other Mondays still count as classes.
      final next = await attendance.loadReport(DateTime(2020, 3, 23));
      expect(next.trainingCancelled, isFalse);
      expect(next.sessionHeld, isTrue);
      expect(next.absent, hasLength(2));

      // Removing the cancellation brings the day back exactly as it was.
      await schedule.setCancelled(monday, false);
      report = await attendance.loadReport(monday);
      expect(report.trainingCancelled, isFalse);
      expect(report.present, hasLength(1));
      expect(report.absent.single.name, 'Ben Reyes');
    });

    test('a cancelled day off the schedule is still marked cancelled', () async {
      await enrol('Ana Cruz');
      await schedule.save({_monday});
      final tuesday = DateTime(2020, 3, 17);

      await schedule.setCancelled(tuesday, true);
      final report = await attendance.loadReport(tuesday);

      expect(report.trainingCancelled, isTrue);
      expect(report.absent, isEmpty);
    });
  });

  group("a student's calendar", () {
    test('cancelled days are in neither the present nor the absent days', () async {
      final ana = await enrol('Ana Cruz');
      await schedule.save({_monday});
      await attendance.checkIn(ana, now: DateTime(2020, 3, 2, 9));
      await attendance.checkIn(ana, now: DateTime(2020, 3, 16, 9));

      var month = await attendance.loadMonth(ana.id!, DateTime(2020, 3));
      expect(month.presentDays, {2, 16});
      expect(month.absentDays, {9, 23, 30});
      expect(month.cancelledDays, isEmpty);

      // One cancelled day had a check-in, the other would have been absent.
      await schedule.setCancelled(DateTime(2020, 3, 16), true);
      await schedule.setCancelled(DateTime(2020, 3, 9), true);
      month = await attendance.loadMonth(ana.id!, DateTime(2020, 3));
      expect(month.presentDays, {2});
      expect(month.absentDays, {23, 30});
      expect(month.cancelledDays, {9, 16});

      // A cancelled day that is not a class weekday shows too.
      await schedule.setCancelled(DateTime(2020, 3, 4), true);
      month = await attendance.loadMonth(ana.id!, DateTime(2020, 3));
      expect(month.cancelledDays, {4, 9, 16});
      expect(month.absentDays, {23, 30});

      // Take the cancellations away and every count is back.
      for (final day in [4, 9, 16]) {
        await schedule.setCancelled(DateTime(2020, 3, day), false);
      }
      month = await attendance.loadMonth(ana.id!, DateTime(2020, 3));
      expect(month.presentDays, {2, 16});
      expect(month.absentDays, {9, 23, 30});
      expect(month.cancelledDays, isEmpty);
    });

    test('days attended and last scanned ignore a cancelled day', () async {
      final ana = await enrol('Ana Cruz');
      await attendance.checkIn(ana, now: DateTime(2020, 3, 2, 9, 30));
      await attendance.checkIn(ana, now: DateTime(2020, 3, 4, 18, 5));

      var history = await attendance.loadHistory(ana.id!);
      expect(history.daysAttended, 2);
      expect(history.lastScanned, DateTime(2020, 3, 4, 18, 5));

      await schedule.setCancelled(DateTime(2020, 3, 4), true);
      history = await attendance.loadHistory(ana.id!);
      expect(history.daysAttended, 1);
      expect(history.lastScanned, DateTime(2020, 3, 2, 9, 30));
      expect(history.records.single.day, '2020-03-02');

      // The check-in itself was kept, so it counts again once restored.
      expect(await _attendanceRows(), 2);
      await schedule.setCancelled(DateTime(2020, 3, 4), false);
      expect((await attendance.loadHistory(ana.id!)).daysAttended, 2);
    });
  });

  group('scanning', () {
    test('nobody is checked in on a cancelled day', () async {
      final ana = await enrol('Ana Cruz');
      final day = DateTime(2020, 3, 16, 9);
      await schedule.setCancelled(day, true);

      final byCode = await attendance.checkInScanned(
        StudentQr.encode(ana.uid),
        now: day,
      );
      expect(byCode.status, CheckInStatus.trainingCancelled);
      expect(byCode.student?.name, 'Ana Cruz');

      final byNumber = await attendance.checkInByStudentNo('1', now: day);
      expect(byNumber.status, CheckInStatus.trainingCancelled);

      expect(await _attendanceRows(), 0);
      expect(await attendance.loadDay(day), isEmpty);

      // The day after is a normal day.
      final nextDay = await attendance.checkIn(
        ana,
        now: DateTime(2020, 3, 17, 9),
      );
      expect(nextDay.status, CheckInStatus.recorded);

      // And the cancelled day takes check-ins again once it is put back.
      await schedule.setCancelled(day, false);
      final restored = await attendance.checkIn(ana, now: day);
      expect(restored.status, CheckInStatus.recorded);
      expect(await attendance.loadDay(day), hasLength(1));
    });

    test('a check-in made before the day was cancelled is hidden, not lost',
        () async {
      final ana = await enrol('Ana Cruz');
      final day = DateTime(2020, 3, 16, 9);
      await attendance.checkIn(ana, now: day);
      expect(await attendance.loadDay(day), hasLength(1));

      await schedule.setCancelled(day, true);
      expect(await attendance.loadDay(day), isEmpty);
      expect(
        (await attendance.checkIn(ana, now: day)).status,
        CheckInStatus.trainingCancelled,
      );
      expect(await _attendanceRows(), 1);

      await schedule.setCancelled(day, false);
      expect(await attendance.loadDay(day), hasLength(1));
    });
  });

  group('backup', () {
    test('cancelled dates travel in a backup and only ever add', () async {
      await schedule.saveCancelled({'2020-03-16', '2020-03-23'});
      final file = await backup.exportBytes();
      final document =
          jsonDecode(utf8.decode(file)) as Map<String, Object?>;
      expect(document['cancelledDates'], ['2020-03-16', '2020-03-23']);

      // Another device that cancelled one of them and another day of its own.
      await _freshDatabase();
      await schedule.saveCancelled({'2020-03-23', '2020-04-06'});
      await backup.importBytes(file);

      expect(await schedule.loadCancelled(), {
        '2020-03-16',
        '2020-03-23',
        '2020-04-06',
      });
    });

    test('a backup without cancelled dates leaves the ones here alone',
        () async {
      final file = await backup.exportBytes();
      final document =
          jsonDecode(utf8.decode(file)) as Map<String, Object?>;
      expect(document.containsKey('cancelledDates'), isFalse);

      await _freshDatabase();
      await schedule.saveCancelled({'2020-03-16'});
      await backup.importBytes(file);

      expect(await schedule.loadCancelled(), {'2020-03-16'});
    });
  });
}
