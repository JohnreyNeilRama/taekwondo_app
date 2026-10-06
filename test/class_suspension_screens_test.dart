import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/screens/attendance_report_screen.dart';
import 'package:tkd_app/screens/class_days_screen.dart';
import 'package:tkd_app/screens/student_attendance_calendar_screen.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/class_schedule.dart';
import 'package:tkd_app/services/student_storage.dart';
import 'package:tkd_app/theme/app_theme.dart';

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
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// A student enrolled before March 2020 starts, with classes on Mondays and
/// Monday the 16th cancelled.
Future<Student> _seedMarch2020(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final student = await StudentStorage().insert(
      Student(
        name: 'Ana Cruz',
        createdAt: DateTime(2020, 3, 1).toIso8601String(),
      ),
    );
    await ClassSchedule().save({DateTime.monday});
    await ClassSchedule().setCancelled(DateTime(2020, 3, 16), true);
    return student;
  }))!;
}

Future<Set<String>> _cancelled(WidgetTester tester) async =>
    (await tester.runAsync(() => ClassSchedule().loadCancelled()))!;

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

  testWidgets('Class days: tap any date to cancel training, tap again to '
      'remove it', (WidgetTester tester) async {
    _tallView(tester);
    await tester.pumpWidget(const MaterialApp(home: ClassDaysScreen()));
    await _settle(tester);

    final now = DateTime.now();
    final label = '${_monthNames[now.month - 1]} 15';
    final key = ClassSchedule.dayKey(DateTime(now.year, now.month, 15));
    expect(find.bySemanticsLabel(label), findsOneWidget);
    expect(await _cancelled(tester), isEmpty);

    // Cancel the 15th.
    await tester.tap(find.bySemanticsLabel(label));
    await _settle(tester);
    expect(find.bySemanticsLabel('$label, training cancelled'), findsOneWidget);
    expect(find.textContaining('Training cancelled on'), findsOneWidget);
    expect(await _cancelled(tester), {key});

    // It is highlighted yellow.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Ink &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color == AppColors.cancelled,
      ),
      findsOneWidget,
    );

    // Tap it again to put it back.
    await tester.tap(find.bySemanticsLabel('$label, training cancelled'));
    await _settle(tester);
    expect(find.bySemanticsLabel(label), findsOneWidget);
    expect(find.textContaining('Cancellation removed'), findsOneWidget);
    expect(await _cancelled(tester), isEmpty);
  });

  testWidgets('Class days: the snackbar Undo takes a cancellation back', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    await tester.pumpWidget(const MaterialApp(home: ClassDaysScreen()));
    await _settle(tester);

    final now = DateTime.now();
    final label = '${_monthNames[now.month - 1]} 20';

    await tester.tap(find.bySemanticsLabel(label));
    await _settle(tester);
    expect(await _cancelled(tester), hasLength(1));

    await tester.tap(find.text('Undo'));
    await _settle(tester);

    expect(find.bySemanticsLabel(label), findsOneWidget);
    expect(await _cancelled(tester), isEmpty);
  });

  testWidgets('the student calendar shows a cancelled Monday in yellow and '
      'does not count it', (WidgetTester tester) async {
    _tallView(tester);
    final student = await _seedMarch2020(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: StudentAttendanceCalendarScreen(
          student: student,
          initialMonth: DateTime(2020, 3),
        ),
      ),
    );
    await _settle(tester);

    // Green / red / yellow / uncoloured: the 16th is cancelled, the other
    // Mondays were missed, the other days are not class days.
    expect(find.bySemanticsLabel('March 16, training cancelled'), findsOneWidget);
    expect(find.bySemanticsLabel('March 16, absent'), findsNothing);
    for (final day in [2, 9, 23, 30]) {
      expect(find.bySemanticsLabel('March $day, absent'), findsOneWidget);
    }
    expect(find.bySemanticsLabel('March 17, no record'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Ink &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color == AppColors.cancelled,
      ),
      findsOneWidget,
    );
    // The legend names the yellow.
    expect(find.text('Training cancelled'), findsOneWidget);
  });

  testWidgets('the student calendar can cancel a day and remove the '
      'cancellation again', (WidgetTester tester) async {
    _tallView(tester);
    final student = await _seedMarch2020(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: StudentAttendanceCalendarScreen(
          student: student,
          initialMonth: DateTime(2020, 3),
        ),
      ),
    );
    await _settle(tester);

    // Cancel another Monday from its absent day.
    await tester.tap(find.bySemanticsLabel('March 9, absent'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Training cancelled'));
    await _settle(tester);
    expect(find.bySemanticsLabel('March 9, training cancelled'), findsOneWidget);
    expect(await _cancelled(tester), {'2020-03-09', '2020-03-16'});

    // Put the 16th back: it is an absence again.
    await tester.tap(find.bySemanticsLabel('March 16, training cancelled'));
    await _settle(tester);
    await tester.tap(find.text('Remove cancellation'));
    await _settle(tester);
    expect(find.bySemanticsLabel('March 16, absent'), findsOneWidget);
    expect(await _cancelled(tester), {'2020-03-09'});
  });

  testWidgets('the attendance report shows a cancelled day as neither present '
      'nor absent', (WidgetTester tester) async {
    _tallView(tester);
    await _seedMarch2020(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceReportScreen(initialDay: DateTime(2020, 3, 16)),
      ),
    );
    await _settle(tester);

    expect(find.textContaining('Training was cancelled on this day'),
        findsOneWidget);
    expect(find.text('Present (-)'), findsOneWidget);
    expect(find.text('Absent (-)'), findsOneWidget);

    // Removing the cancellation makes it an ordinary class day again.
    await tester.tap(find.text('Remove cancellation'));
    await _settle(tester);

    expect(find.textContaining('Training was cancelled on this day'),
        findsNothing);
    expect(find.text('Present (0)'), findsOneWidget);
    expect(find.text('Absent (1)'), findsOneWidget);
    expect(await _cancelled(tester), isEmpty);
  });
}
