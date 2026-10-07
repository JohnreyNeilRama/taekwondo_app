import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/main.dart';
import 'package:tkd_app/screens/security_gate.dart';
import 'package:tkd_app/screens/students_screen.dart';
import 'package:tkd_app/services/app_database.dart';

/// The belt Quick Cards open the students of a colour.
///
/// Same shape as `test/widget_test.dart`: real SQLite through the FFI
/// implementation, alternating real time (for the database) and frames (for
/// the navigation animations) so both kinds of async work finish.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 80));
  }
}

/// Starts the app on its own empty in-memory database, with the security gate
/// already open so the tests are about the Promotion page, not about signing
/// in. Wide and tall, so every Quick Card is on screen and can be tapped.
Future<void> _startApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.runAsync(() async {
    await AppDatabase.debugReset();
    AppDatabase.debugOverridePath = inMemoryDatabasePath;
  });
  SecurityGate.debugSkipLock = true;
  // The QR screen that opens after a student is added is not what these tests
  // are about; it has its own test in test/student_qr_screen_test.dart.
  StudentsScreen.debugSkipQrAfterAdd = true;
  await tester.runAsync(() => AppDatabase.instance.database);
  await tester.pumpWidget(const TkdApp());
  await _settle(tester);
}

/// Adds a student through the registry, then records the given [belt] for them
/// on the Promotion page, leaving the Promotion page on screen. Mirrors the
/// Pending -> picker -> form flow the app uses.
Future<void> _addStudentWithBelt(
  WidgetTester tester,
  String name,
  String belt,
) async {
  await tester.tap(find.text('Add Student').first);
  await _settle(tester);
  await tester.enterText(
    find.widgetWithText(TextField, 'Enter full name'),
    name,
  );
  await tester.tap(find.text('Save Student'));
  await _settle(tester);

  await tester.tap(find.text('Promotion').last);
  await _settle(tester);
  await tester.tap(find.widgetWithText(FilledButton, 'Pending (1)'));
  await _settle(tester);
  await tester.tap(find.text(name).last);
  await _settle(tester);

  // The form opens on the entry grade; open the menu and choose [belt].
  await tester.tap(find.text('9th Grade White'));
  await _settle(tester);
  await tester.tap(find.text(belt).last);
  await _settle(tester);
  await tester.tap(find.text('Save Record'));
  await _settle(tester);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDownAll(() async {
    await AppDatabase.debugReset();
    SecurityGate.debugSkipLock = false;
  });

  testWidgets('a belt Quick Card opens the students of that colour', (
    WidgetTester tester,
  ) async {
    await _startApp(tester);
    await _addStudentWithBelt(tester, 'Nguyen Van A', '8th Grade Yellow');

    // The student is counted on the Yellow card and no other.
    expect(
      find.descendant(
        of: find.widgetWithText(Container, 'Yellow Belts'),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    // Tapping the card opens that colour's list. The subtitle (unique to the
    // opened list) confirms it holds exactly the one student the card counted.
    await tester.tap(find.text('Yellow Belts'));
    await _settle(tester);
    expect(find.text('1 student'), findsOneWidget);
    expect(find.text('No students assigned to this belt yet'), findsNothing);

    // The student's row is there, with their registry number.
    expect(find.text('Nguyen Van A'), findsWidgets);
    expect(find.text('TKD-0001'), findsWidgets);

    // Back returns to the Promotion page.
    await tester.tap(find.byTooltip('Back'));
    await _settle(tester);
    expect(find.text('Promotion Test Record'), findsOneWidget);
    expect(find.text('1 student'), findsNothing);
  });

  testWidgets('an empty belt Quick Card says so', (WidgetTester tester) async {
    await _startApp(tester);
    await _addStudentWithBelt(tester, 'Nguyen Van A', '8th Grade Yellow');

    // Nobody holds a white belt yet, so its card opens an explanation rather
    // than an empty list.
    await tester.tap(find.text('White Belts'));
    await _settle(tester);
    expect(find.text('No students assigned to this belt yet'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await _settle(tester);
    expect(find.text('Promotion Test Record'), findsOneWidget);
  });
}
