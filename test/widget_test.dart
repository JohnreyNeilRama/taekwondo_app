import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tkd_app/main.dart';
import 'package:tkd_app/services/student_storage.dart';

late Directory _tempDir;

/// The registry is stored with real file I/O, which only completes on
/// the real event loop — pumpAndSettle alone never sees it finish.
/// [WidgetTester.runAsync] yields real time so reads and writes can
/// complete; the frames that the resulting setState calls schedule are
/// then flushed with pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    // Tests point storage at a throwaway temp file so they never
    // touch real data.
    _tempDir = await Directory.systemTemp.createTemp('tkd_app_test');
    StudentStorage.debugOverrideFile = File('${_tempDir.path}/students.json');
  });

  tearDownAll(() async {
    StudentStorage.debugOverrideFile = null;
    // Give any in-flight write a moment to release its file handle,
    // then clean up best-effort — a failed cleanup must not fail tests.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    try {
      if (_tempDir.existsSync()) {
        await _tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  testWidgets('Students screen: empty state, add student, search', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TkdApp());
    await _settle(tester);

    // Empty state on first launch.
    expect(find.text('TKD Records'), findsOneWidget);
    expect(find.text('All Students'), findsOneWidget);
    expect(find.text('0 records'), findsOneWidget);
    expect(find.text('No student records found.'), findsOneWidget);

    // Add a student through the Taekwondo Information Sheet form.
    await tester.tap(find.text('+ Add Student').first);
    await _settle(tester);
    expect(find.text('STUDENT DETAILS'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter full name'),
      'Nguyen Van A',
    );
    await tester.tap(find.text('Save Student'));
    await _settle(tester);

    expect(find.text('Nguyen Van A'), findsOneWidget);
    expect(find.text('1 record'), findsOneWidget);
    expect(find.text('No student records found.'), findsNothing);

    // The redesigned card shows the registry badge and both actions.
    expect(find.text('TKD-0001'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);

    // A search with no match brings the empty state back.
    await tester.enterText(find.byType(TextField), 'Tran');
    await tester.pump();

    expect(find.text('0 results for "Tran"'), findsOneWidget);
    expect(find.text('No student records found.'), findsOneWidget);
  });

  testWidgets('Bottom navigation switches to Profile', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TkdApp());
    await _settle(tester);

    await tester.tap(find.text('Profile').last);
    await _settle(tester);

    expect(find.text('Profile coming soon'), findsOneWidget);
  });

  testWidgets('Tapping a student opens the detail screen and editing saves changes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TkdApp());
    await _settle(tester);

    // Seed one student.
    await tester.tap(find.text('+ Add Student').first);
    await _settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter full name'),
      'Nguyen Van A',
    );
    await tester.tap(find.text('Save Student'));
    await _settle(tester);

    // Tap the tile to open the detail screen.
    await tester.tap(find.text('Nguyen Van A'));
    await _settle(tester);
    expect(find.text('Delete Student'), findsOneWidget);
    expect(find.text('Save Student'), findsNothing);

    // Enter edit mode: the form opens prefilled.
    await tester.tap(find.byTooltip('Edit'));
    await _settle(tester);
    expect(find.text('Save Changes'), findsOneWidget);
    final nameField = find.widgetWithText(TextField, 'Enter full name');
    expect(
      tester.widget<TextField>(nameField).controller!.text,
      'Nguyen Van A',
    );

    // Change the name and save.
    await tester.enterText(nameField, 'Nguyen Van B');
    await tester.tap(find.text('Save Changes'));
    await _settle(tester);

    // Back on the list, the updated name is shown.
    expect(find.text('Nguyen Van B'), findsOneWidget);
    expect(find.text('Nguyen Van A'), findsNothing);
  });

  testWidgets('Deleting a student from the detail screen removes it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TkdApp());
    await _settle(tester);

    await tester.tap(find.text('+ Add Student').first);
    await _settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter full name'),
      'Nguyen Van A',
    );
    await tester.tap(find.text('Save Student'));
    await _settle(tester);

    await tester.tap(find.text('Nguyen Van A'));
    await _settle(tester);

    await tester.tap(find.text('Delete Student'));
    await _settle(tester);
    expect(find.text('Delete student?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await _settle(tester);

    expect(find.text('0 records'), findsOneWidget);
    expect(find.text('Nguyen Van A'), findsNothing);
  });

  testWidgets('Card Edit button opens the form directly in edit mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TkdApp());
    await _settle(tester);

    // Seed one student.
    await tester.tap(find.text('+ Add Student').first);
    await _settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter full name'),
      'Nguyen Van A',
    );
    await tester.tap(find.text('Save Student'));
    await _settle(tester);

    // The card's Edit button goes straight to a prefilled form —
    // without the detail screen in between.
    await tester.tap(find.text('Edit'));
    await _settle(tester);
    expect(find.text('Save Changes'), findsOneWidget);
    final nameField = find.widgetWithText(TextField, 'Enter full name');
    expect(
      tester.widget<TextField>(nameField).controller!.text,
      'Nguyen Van A',
    );

    // Saving brings the change back onto the card.
    await tester.enterText(nameField, 'Nguyen Van B');
    await tester.tap(find.text('Save Changes'));
    await _settle(tester);
    expect(find.text('Nguyen Van B'), findsOneWidget);
    expect(find.text('TKD-0001'), findsOneWidget);
  });
}

