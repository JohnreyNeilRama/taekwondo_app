import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/screens/students_screen.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/student_storage.dart';
import 'package:tkd_app/widgets/student_avatar.dart';

/// A real 1 x 1 transparent PNG: the bytes an uploaded picture is saved as.
final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
]);

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

/// A view big enough that every card is on screen and can be tapped.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Opens the Students page on its own, the way selecting the destination does,
/// so it reads the rows already saved on the real database.
Future<void> _openStudents(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: StudentsScreen())),
  );
  await _settle(tester);
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

  testWidgets('the card shows the family name first and hides the registry '
      'number and the contact number', (WidgetTester tester) async {
    _tallView(tester);
    await tester.runAsync(
      () =>
          StudentStorage().insert(const Student(name: 'Juan Miguel Dela Cruz')),
    );
    await _openStudents(tester);

    // Family name first, with the given names after it.
    expect(find.text('Dela Cruz, Juan Miguel'), findsOneWidget);
    expect(find.text('Juan Miguel Dela Cruz'), findsNothing);
    // The registry number, the old View button and the contact row are gone.
    expect(find.text('TKD-0001'), findsNothing);
    expect(find.text('View'), findsNothing);
    expect(find.text('Contact'), findsNothing);
  });

  testWidgets('cards are ordered by family name, then given name', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    await tester.runAsync(() async {
      await StudentStorage().insert(const Student(name: 'Ben Reyes'));
      await StudentStorage().insert(const Student(name: 'Ana Cruz'));
      await StudentStorage().insert(
        const Student(name: 'Juan Miguel Dela Cruz'),
      );
    });
    await _openStudents(tester);

    final cruz = tester.getTopLeft(find.text('Cruz, Ana')).dy;
    final dela = tester.getTopLeft(find.text('Dela Cruz, Juan Miguel')).dy;
    final reyes = tester.getTopLeft(find.text('Reyes, Ben')).dy;
    expect(cruz, lessThan(dela));
    expect(dela, lessThan(reyes));
  });

  testWidgets('tapping the card opens the details; Edit (in the menu) opens the form', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    await tester.runAsync(
      () =>
          StudentStorage().insert(const Student(name: 'Juan Miguel Dela Cruz')),
    );
    await _openStudents(tester);

    // The whole card opens the read-only details.
    await tester.tap(find.text('Dela Cruz, Juan Miguel'));
    await _settle(tester);
    expect(find.text('STUDENT DETAILS'), findsOneWidget);
    expect(find.text('Delete Student'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await _settle(tester);

    // The Edit action is in the three-dot menu, not on the card itself.
    await tester.tap(find.byTooltip('More options'));
    await _settle(tester);
    await tester.tap(find.text('Edit'));
    await _settle(tester);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Delete Student'), findsNothing);
  });

  testWidgets('tapping the picture opens it larger, with a way to close', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    await tester.runAsync(
      () => StudentStorage().insert(
        Student(name: 'Jrey Neil', photoBase64: base64Encode(_png)),
      ),
    );
    await _openStudents(tester);

    expect(find.byType(Dialog), findsNothing);
    await tester.tap(find.byType(StudentAvatar));
    await _settle(tester);

    // A dialog with the larger picture is up, and the details were not opened.
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('STUDENT DETAILS'), findsNothing);
    expect(find.byTooltip('Close'), findsOneWidget);

    // The Close button dismisses it.
    await tester.tap(find.byTooltip('Close'));
    await _settle(tester);
    expect(find.byType(Dialog), findsNothing);
  });
}
