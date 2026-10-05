import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/screens/student_detail_screen.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/attendance_storage.dart';
import 'package:tkd_app/services/student_storage.dart';
import 'package:tkd_app/widgets/attendance_history_card.dart';

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

/// A view big enough that the whole page is on screen and can be tapped.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Saves a student with a check-in on each of [days] (March 2020, far enough in
/// the past that the page always shows full dates, never "Today") and opens
/// their page.
Future<Student> _openStudent(
  WidgetTester tester, {
  List<DateTime> days = const [],
}) async {
  final saved = (await tester.runAsync(() async {
    final student = await StudentStorage().insert(
      const Student(name: 'Ana Cruz'),
    );
    for (final day in days) {
      await AttendanceStorage().checkIn(student, now: day);
    }
    return student;
  }))!;
  await tester.pumpWidget(
    MaterialApp(home: StudentDetailScreen(student: saved)),
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

  testWidgets('the page shows the days attended, the last scan and the list', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    await _openStudent(
      tester,
      days: [DateTime(2020, 3, 2, 9, 30), DateTime(2020, 3, 4, 18, 5)],
    );

    expect(find.text('ATTENDANCE'), findsOneWidget);
    expect(find.text('Days attended'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AttendanceHistoryCard),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(find.text('Last scanned'), findsOneWidget);
    expect(find.text('Mar 4, 2020, 6:05 PM'), findsOneWidget);

    // Newest first, each with the time it was recorded.
    expect(find.text('Wed, Mar 4, 2020'), findsOneWidget);
    expect(find.text('Mon, Mar 2, 2020'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Wed, Mar 4, 2020')).dy,
      lessThan(tester.getTopLeft(find.text('Mon, Mar 2, 2020')).dy),
    );
    // The rest of the sheet is still there.
    expect(find.text('STUDENT DETAILS'), findsOneWidget);
  });

  testWidgets('a student who was never scanned says so', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    await _openStudent(tester);

    expect(
      find.descendant(
        of: find.byType(AttendanceHistoryCard),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    expect(find.text('Never'), findsOneWidget);
    expect(find.textContaining('No check-ins yet'), findsOneWidget);
    expect(find.byTooltip('Undo this scan'), findsNothing);
  });

  testWidgets('undo asks first, then removes the mistaken scan', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    await _openStudent(
      tester,
      days: [DateTime(2020, 3, 2, 9, 30), DateTime(2020, 3, 4, 18, 5)],
    );

    // The newest scan is the first row.
    await tester.tap(find.byTooltip('Undo this scan').first);
    await _settle(tester);
    expect(find.text('Undo this scan?'), findsOneWidget);
    expect(find.textContaining('Wed, Mar 4, 2020'), findsWidgets);

    await tester.tap(find.text('Remove check-in'));
    await _settle(tester);

    expect(find.text('Undo this scan?'), findsNothing);
    expect(find.text('Check-in removed'), findsOneWidget);
    expect(find.text('Wed, Mar 4, 2020'), findsNothing);
    expect(find.text('Mon, Mar 2, 2020'), findsOneWidget);
    // The last scan falls back to the one before it.
    expect(find.text('Mar 2, 2020, 9:30 AM'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AttendanceHistoryCard),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(await _rows(tester), 1);
  });

  testWidgets('cancelling the undo keeps the scan', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    await _openStudent(tester, days: [DateTime(2020, 3, 2, 9, 30)]);

    await tester.tap(find.byTooltip('Undo this scan'));
    await _settle(tester);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);

    expect(find.text('Undo this scan?'), findsNothing);
    expect(find.text('Mon, Mar 2, 2020'), findsOneWidget);
    expect(await _rows(tester), 1);
  });

  testWidgets('a long history lists five check-ins until "Show all"', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    await _openStudent(
      tester,
      days: [for (var day = 1; day <= 7; day++) DateTime(2020, 3, day, 9, 0)],
    );

    expect(find.byTooltip('Undo this scan'), findsNWidgets(5));
    expect(find.text('Show all 7'), findsOneWidget);

    await tester.tap(find.text('Show all 7'));
    await _settle(tester);
    expect(find.byTooltip('Undo this scan'), findsNWidgets(7));

    await tester.tap(find.text('Show fewer'));
    await _settle(tester);
    expect(find.byTooltip('Undo this scan'), findsNWidgets(5));
  });
}
