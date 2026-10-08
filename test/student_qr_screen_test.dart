import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/main.dart';
import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/screens/security_gate.dart';
import 'package:tkd_app/screens/student_qr_screen.dart';
import 'package:tkd_app/screens/students_screen.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/student_uid.dart';
import 'package:tkd_app/widgets/app_nav_bar.dart';

/// Flushes the database work and the frames the screens need: real SQLite only
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

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDownAll(() async {
    await AppDatabase.debugReset();
    SecurityGate.debugSkipLock = false;
    StudentsScreen.debugSkipQrAfterAdd = false;
  });

  testWidgets('the QR screen draws a code made from the student uid', (
    WidgetTester tester,
  ) async {
    final uid = StudentUid.generate();
    await tester.pumpWidget(
      MaterialApp(
        home: StudentQrScreen(
          student: Student(id: 1, uid: uid, name: 'Nguyen Van A'),
        ),
      ),
    );

    expect(find.text('Student QR code'), findsOneWidget);
    expect(find.text('Nguyen Van A'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    // The "just added" note belongs to the screen that opens after a save only.
    expect(find.textContaining('was added'), findsNothing);
  });

  testWidgets('a student without a uid shows a message instead of a code', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StudentQrScreen(student: Student(id: 1, name: 'Nguyen Van A')),
      ),
    );

    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('no QR identity'), findsOneWidget);
  });

  testWidgets('adding a student opens their QR code, and Done returns to the '
      'list', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await AppDatabase.debugReset();
      AppDatabase.debugOverridePath = inMemoryDatabasePath;
    });
    SecurityGate.debugSkipLock = true;
    StudentsScreen.debugSkipQrAfterAdd = false;
    await tester.runAsync(() => AppDatabase.instance.database);
    await tester.pumpWidget(const TkdApp());
    await _settle(tester);

    await tester.tap(find.text('Add Student').first);
    await _settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter full name'),
      'Nguyen Van A',
    );
    await tester.tap(find.text('Save Student'));
    await _settle(tester);

    // The QR screen is up, with the code of the student just saved.
    expect(find.text('Student saved'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);

    await tester.tap(find.text('Done'));
    await _settle(tester);

    expect(find.text('A, Nguyen Van'), findsOneWidget);
    expect(find.text('1 record'), findsOneWidget);
  });

  testWidgets('the bar has a QR button in the middle that is not a page', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await AppDatabase.debugReset();
      AppDatabase.debugOverridePath = inMemoryDatabasePath;
    });
    SecurityGate.debugSkipLock = true;
    await tester.runAsync(() => AppDatabase.instance.database);
    await tester.pumpWidget(const TkdApp());
    await _settle(tester);

    final bar = tester.widget<AppNavBar>(find.byType(AppNavBar));
    expect(AppNavBar.labels, [
      'Students',
      'Promotion',
      'Scan',
      'Achievement',
      'Settings',
    ]);
    // Students is the page on screen, and it sits in the first slot.
    expect(bar.selected, 0);
    // The Scan slot is the middle one, and it is an action, never selected.
    expect(AppNavBar.labels[AppNavBar.scanSlot], 'Scan');
    for (final label in AppNavBar.labels) {
      expect(
        find.descendant(
          of: find.byType(AppNavBar),
          matching: find.text(label),
        ),
        findsOneWidget,
        reason: '$label should be on the bottom bar',
      );
    }
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
  });
}
