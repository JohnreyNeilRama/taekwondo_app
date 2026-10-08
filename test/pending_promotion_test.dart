import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/promotion_record.dart';
import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/screens/promotion_screen.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/promotion_storage.dart';
import 'package:tkd_app/services/student_storage.dart';

/// Flushes the database work and the frames the screens need, the same way the
/// app own widget test does: real SQLite only answers on the real event loop,
/// so real time is yielded with [WidgetTester.runAsync] while frames are pumped
/// on the fake clock.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 80));
  }
}

/// Gives the test its own empty in-memory database, so no test can see another
/// one records and the registry on the device is never touched.
///
/// The reset runs inside [WidgetTester.runAsync] on purpose: closing the
/// previous database is real SQLite work that only completes on the real event
/// loop. Awaiting it from `setUp` or `tearDown` (which run on the fake clock of
/// a widget test) is what used to hang the whole test run.
Future<void> _freshDatabase(WidgetTester tester) async {
  await tester.runAsync(() async {
    await AppDatabase.debugReset();
    AppDatabase.debugOverridePath = inMemoryDatabasePath;
  });
}

/// Opens [page] the way selecting the destination does: the previous screen is
/// unmounted first, so the page starts from `initState` and reads the saved
/// rows again instead of keeping the state of an earlier visit.
Future<void> _openPage(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
  await _settle(tester);
}

/// Saves one student who has no belt yet and one who already has theirs.
Future<void> _seed() async {
  final students = StudentStorage();
  await students.insert(const Student(name: 'Jrey Neil'));
  final promoted = await students.insert(const Student(name: 'Ann Cruz'));
  await PromotionStorage().saveForStudent(
    PromotionRecord(
      studentId: promoted.id!,
      belt: '9th Grade White',
      lastPromotionDate: '01/05/2026',
    ),
  );
}

void main() {
  setUpAll(() {
    // The screens read and write the real database, so it is opened through
    // the FFI implementation instead of a platform channel.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Every test starts from its own database through [_freshDatabase]; this only
  // closes the last one, outside any test, where real time is available.
  tearDownAll(() async {
    await AppDatabase.debugReset();
  });

  testWidgets('Pending holds the registry students who have no belt', (
    WidgetTester tester,
  ) async {
    await _freshDatabase(tester);
    await tester.runAsync(_seed);
    await _openPage(tester, const PromotionScreen());

    // One of the two students is waiting for a belt; the other already has one
    // and is listed under their grade instead of in Pending.
    expect(find.text('Pending (1)'), findsOneWidget);
    expect(find.text('Ann Cruz'), findsOneWidget);
    expect(find.text('Jrey Neil'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Pending (1)'));
    await _settle(tester);

    // The Pending list offers exactly the student who still needs a belt.
    expect(find.text('Pending Students'), findsOneWidget);
    expect(
      find.text('These students are waiting to be assigned a belt.'),
      findsOneWidget,
    );
    expect(find.text('Jrey Neil'), findsOneWidget);
    expect(find.text('Ann Cruz'), findsNothing);

    // Choosing them opens the promotion form for that same registry record.
    await tester.tap(find.text('Jrey Neil'));
    await _settle(tester);
    expect(find.text('Add Promotion'), findsOneWidget);
    expect(find.text('PROMOTION DETAILS'), findsOneWidget);

    // The Belt menu opens on the lowest grade and lists the curriculum.
    await tester.tap(find.text('9th Grade White'));
    await _settle(tester);
    expect(find.text('9th Grade White'), findsNWidgets(2));
    await tester.tap(find.text('8th Grade Yellow').last);
    await _settle(tester);
    await tester.tap(find.text('Save Record'));
    await _settle(tester);

    // The belt is saved against the student that was already in the registry:
    // they appear on the belt list and Pending is empty again.
    expect(find.text('Jrey Neil'), findsOneWidget);
    expect(find.text('TKD-0001'), findsNothing);
    expect(find.text('8th Grade Yellow'), findsOneWidget);
    expect(find.text('Pending (0)'), findsOneWidget);

    // Opening Pending again says there is nothing left to assign.
    await tester.tap(find.widgetWithText(FilledButton, 'Pending (0)'));
    await _settle(tester);
    expect(find.text('No pending students'), findsOneWidget);
    expect(
      find.text('Every student in your registry already has a belt.'),
      findsOneWidget,
    );

    // No student was created along the way: the registry still holds two.
    expect(await tester.runAsync(StudentStorage().loadStudents), hasLength(2));
  });

  testWidgets('a student added on the Students page waits in Pending', (
    WidgetTester tester,
  ) async {
    await _freshDatabase(tester);
    await _openPage(tester, const PromotionScreen());

    // With an empty registry there is nobody to assign a belt to.
    expect(find.text('Pending (0)'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Pending (0)'));
    await _settle(tester);
    expect(find.text('No students yet'), findsOneWidget);

    // Adding a student on the Students page is what puts them in Pending: no
    // belt record points at them yet.
    await tester.runAsync(
      () => StudentStorage().insert(const Student(name: 'Jrey Neil')),
    );

    // The Promotion page re-reads the registry whenever the destination is
    // selected, so the count follows the registry with no extra bookkeeping.
    await _openPage(tester, const PromotionScreen());
    expect(find.text('Pending (1)'), findsOneWidget);
    expect(find.text('No promotion records yet'), findsOneWidget);
  });
}