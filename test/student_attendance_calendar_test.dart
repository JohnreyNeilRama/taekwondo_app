import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/screens/student_attendance_calendar_screen.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/attendance_storage.dart';
import 'package:tkd_app/services/student_storage.dart';

/// Flushes the database work and the frames the page needs: real SQLite only
/// answers on the real event loop, so real time is yielded with
/// [WidgetTester.runAsync] while frames are pumped on the fake clock.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<Student> _openCalendar(
  WidgetTester tester, {
  List<DateTime> days = const [],
}) async {
  final saved = (await tester.runAsync(() async {
    final student = await StudentStorage().insert(
      Student(name: 'Ana Cruz', createdAt: DateTime(2020, 3, 1).toIso8601String()),
    );
    for (final day in days) {
      await AttendanceStorage().checkIn(student, now: day);
    }
    return student;
  }))!;
  await tester.pumpWidget(
    MaterialApp(
      home: StudentAttendanceCalendarScreen(
        student: saved,
        initialMonth: DateTime(2020, 3),
      ),
    ),
  );
  await _settle(tester);
  return saved;
}

Future<int> _rows(WidgetTester tester) async {
  final db = await tester.runAsync(() => AppDatabase.instance.database);
  final rows = await tester.runAsync(
    () => db!.rawQuery('SELECT COUNT(*) AS total FROM attendance'),
  );
  return rows!.first['total'] as int;
}

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

  testWidgets('tapping a present day can remove that check-in', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    await _openCalendar(tester, days: [DateTime(2020, 3, 4, 9, 30)]);

    await tester.tap(find.bySemanticsLabel('March 4, present'));
    await _settle(tester);

    expect(find.text('Check-in'), findsOneWidget);
    expect(find.textContaining('9:30 AM'), findsOneWidget);

    await tester.tap(find.text('Remove check-in'));
    await _settle(tester);

    expect(find.text('Check-in removed'), findsOneWidget);
    expect(find.bySemanticsLabel('March 4, present'), findsNothing);
    expect(find.bySemanticsLabel('March 4, no record'), findsOneWidget);
    expect(await _rows(tester), 0);
  });

  testWidgets('tapping a day with no record can mark the student present', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    await _openCalendar(tester);

    await tester.tap(find.bySemanticsLabel('March 5, no record'));
    await _settle(tester);

    expect(find.text('Mark present?'), findsOneWidget);
    await tester.tap(find.text('Mark present'));
    await _settle(tester);

    expect(find.text('Marked present'), findsOneWidget);
    expect(find.bySemanticsLabel('March 5, present'), findsOneWidget);
    expect(await _rows(tester), 1);
  });

  testWidgets('closing the check-in dialog leaves the day as it was', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    await _openCalendar(tester, days: [DateTime(2020, 3, 4, 9, 30)]);

    await tester.tap(find.bySemanticsLabel('March 4, present'));
    await _settle(tester);
    await tester.tap(find.text('Close'));
    await _settle(tester);

    expect(find.text('Check-in'), findsNothing);
    expect(find.bySemanticsLabel('March 4, present'), findsOneWidget);
    expect(await _rows(tester), 1);
  });
}
