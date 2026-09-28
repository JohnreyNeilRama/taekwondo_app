import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tkd_app/main.dart';
import 'package:tkd_app/services/achievement_storage.dart';
import 'package:tkd_app/services/promotion_storage.dart';
import 'package:tkd_app/services/student_storage.dart';

late Directory _tempDir;

/// Flushes both kinds of async work this app relies on.
///
/// The storage layer uses real file I/O, which only completes on the real
/// event loop, so real time has to be yielded with
/// [WidgetTester.runAsync]. Navigation transitions and menus, on the other
/// hand, advance on the fake clock, so frames have to be pumped with a
/// duration for them to finish. Alternating the two lets both complete.
///
/// Bounded pumps are used rather than `pumpAndSettle` because an open
/// dropdown or a loading spinner animates indefinitely and would make
/// `pumpAndSettle` never return.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  setUp(() async {
    // Tests point storage at a throwaway temp file so they never
    // touch real data.
    _tempDir = await Directory.systemTemp.createTemp('tkd_app_test');
    StudentStorage.debugOverrideFile = File('${_tempDir.path}/students.json');
    PromotionStorage.debugOverrideFile = File('${_tempDir.path}/promos.json');
    AchievementStorage.debugOverrideFile = File(
      '${_tempDir.path}/achievements.json',
    );
  });

  tearDownAll(() async {
    StudentStorage.debugOverrideFile = null;
    PromotionStorage.debugOverrideFile = null;
    AchievementStorage.debugOverrideFile = null;
    // Give any in-flight write a moment to release its file handle,
    // then clean up best-effort - a failed cleanup must not fail tests.
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

  testWidgets('Bottom navigation switches between the new destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TkdApp());
    await _settle(tester);

    // Promotion: reads the real registry, so with no students saved it
    // explains that the registry must be filled first.
    await tester.tap(find.text('Promotion').last);
    await _settle(tester);
    expect(find.text('Promotion'), findsWidgets);
    expect(find.text('No promotion records yet'), findsOneWidget);
    expect(
      find.text(
        'Add a student on the Students page first, '
        'then record their belt here.',
      ),
      findsOneWidget,
    );

    // The Quick Cards are always on screen — above the search box and the
    // Add Student button — as one card per belt colour, all reading 0 while
    // nothing has been recorded yet.
    for (final label in const [
      'Black Belts',
      'Brown Belts',
      'Red Belts',
      'Blue Belts',
      'Yellow Belts',
      'White Belts',
    ]) {
      expect(find.text(label), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(Container, label),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
    }
    expect(
      tester.getTopLeft(find.text('White Belts')).dy,
      lessThan(tester.getTopLeft(find.byType(TextField)).dy),
    );

    // Achievement: the designed screen, listing the registry one card per
    // student, with the search box and the Add Student action on top.
    await tester.tap(find.text('Achievement').last);
    await _settle(tester);
    expect(find.text('Achievement Record'), findsOneWidget);
    expect(find.text('+ Add Student'), findsOneWidget);
    // The Filter button is gone and the search box now sits in its place, on
    // the same row, left of the Add Student action.
    expect(find.text('Many to one'), findsNothing);
    final searchBox = find.byType(TextField);
    final addButton = find.widgetWithText(FilledButton, '+ Add Student');
    expect(searchBox, findsOneWidget);
    expect(
      tester.getCenter(searchBox).dy,
      closeTo(tester.getCenter(addButton).dy, 1),
    );
    expect(
      tester.getRect(searchBox).right,
      lessThan(tester.getRect(addButton).left),
    );
    expect(find.text('List of Students'), findsOneWidget);
    // No students saved yet, so the list explains where to start.
    expect(find.text('No students yet'), findsOneWidget);

    // Import / Export.
    await tester.tap(find.text('Data').last);
    await _settle(tester);
    expect(find.text('Import / Export Data'), findsOneWidget);
    // "What gets transferred" is further down the scroll view, so the
    // first visible action card is asserted instead.
    expect(find.text('Export backup'), findsOneWidget);

    // Back to the registry.
    await tester.tap(find.text('Students').last);
    await _settle(tester);
    expect(find.text('All Students'), findsOneWidget);
  });

  testWidgets(
    'Promotion "Add Student" offers students added after app launch',
    (WidgetTester tester) async {
      await tester.pumpWidget(const TkdApp());
      await _settle(tester);

      // The Promotion screen is built at launch by the IndexedStack, before
      // any student exists. Adding a student afterwards must still make them
      // selectable from the Promotion picker.
      await tester.tap(find.text('+ Add Student').first);
      await _settle(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Enter full name'),
        'Nguyen Van A',
      );
      await tester.tap(find.text('Save Student'));
      await _settle(tester);

      await tester.tap(find.text('Promotion').last);
      await _settle(tester);
      expect(find.text('No promotion records yet'), findsOneWidget);
      // The picker then reads the registry from disk: real file I/O on the
      // fake clock, so its continuation needs both real time and a frame.
      // The button opens the picker over the existing registry; it never
      // creates a student. The row's own button is the first of the two on
      // screen (the other sits in the empty state below the fold).
      await tester.tap(find.text('Add Student').first);
      await _settle(tester);

      // The picker lists the student that already exists in the registry.
      expect(find.text('Search your students'), findsOneWidget);
      expect(find.text('Nguyen Van A'), findsOneWidget);

      // Choosing them opens the promotion form for that same record.
      await tester.tap(find.text('Nguyen Van A').last);
      await _settle(tester);
      expect(find.text('PROMOTION DETAILS'), findsOneWidget);

      // The Belt menu opens on the lowest grade and lists the curriculum.
      await tester.tap(find.text('9th Grade White'));
      await _settle(tester);
      expect(find.text('9th Grade White'), findsNWidgets(2));
      await tester.tap(find.text('8th Grade Yellow').last);
      await _settle(tester);
      await tester.tap(find.text('Save Record'));
      await _settle(tester);

      // The student now appears on the Promotion list under their grade
      // heading, and that grade is counted on its colour's Quick Card.
      expect(find.text('Nguyen Van A'), findsOneWidget);
      expect(find.text('TKD-0001'), findsOneWidget);
      expect(find.text('8th Grade Yellow'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(Container, 'Yellow Belts'),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );

      // The registry itself is untouched: still exactly one student record.
      await tester.tap(find.text('Students').last);
      await _settle(tester);
      expect(find.text('1 record'), findsOneWidget);
      expect(find.text('Nguyen Van A'), findsOneWidget);
    },
  );

  testWidgets(
    'Tapping a student opens the detail screen and editing saves changes',
    (WidgetTester tester) async {
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
    },
  );

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

    // The card's Edit button goes straight to a prefilled form -
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

  testWidgets('Achievement "Add Student" records an award for a student', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TkdApp());
    await _settle(tester);

    // Seed one student: achievements always attach to the registry.
    await tester.tap(find.text('+ Add Student').first);
    await _settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter full name'),
      'Nguyen Van A',
    );
    await tester.tap(find.text('Save Student'));
    await _settle(tester);

    await tester.tap(find.text('Achievement').last);
    await _settle(tester);
    expect(find.text('Nguyen Van A'), findsOneWidget);

    // "Add Student" opens the floating form instead of creating a student.
    await tester.tap(find.text('+ Add Student'));
    await _settle(tester);
    expect(find.text('Add Achievement'), findsOneWidget);
    expect(find.text('Select a student'), findsOneWidget);
    // Every field of the form, inside the floating dialog. Scoped to the
    // dialog because "Achievement" is also a bottom navigation label.
    for (final label in const ['Student', 'Date', 'Event', 'Achievement']) {
      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text(label)),
        findsOneWidget,
      );
    }

    // The student comes from the existing registry, through the picker.
    await tester.tap(find.text('Select a student'));
    await _settle(tester);
    expect(find.text('Search your students'), findsOneWidget);
    await tester.tap(find.text('Nguyen Van A').last);
    await _settle(tester);
    expect(find.text('Select a student'), findsNothing);

    // Event text field, then the medal dropdown.
    await tester.enterText(
      find.widgetWithText(TextField, 'e.g. National Tournament'),
      'National Tournament',
    );
    await _settle(tester);
    await tester.tap(find.text('Gold'));
    await _settle(tester);
    expect(find.text('Bronze'), findsOneWidget);
    await tester.tap(find.text('Silver').last);
    await _settle(tester);
    await tester.tap(find.text('Save Record'));
    await _settle(tester);

    // The form closes and the award is listed against that student.
    expect(find.text('Add Achievement'), findsNothing);
    expect(find.text('Nguyen Van A'), findsOneWidget);
    expect(find.textContaining('Silver'), findsOneWidget);
    expect(find.text('1 student \u00B7 1 achievement record'), findsOneWidget);

    // Tapping the card opens that student's records.
    await tester.tap(find.text('Nguyen Van A'));
    await _settle(tester);
    expect(find.text('Achievement Details'), findsOneWidget);
    expect(find.text('National Tournament'), findsOneWidget);
    expect(find.text('Silver'), findsOneWidget);

    // The registry itself is untouched: still exactly one student record.
    await tester.tap(find.byTooltip('Back'));
    await _settle(tester);
    await tester.tap(find.text('Students').last);
    await _settle(tester);
    expect(find.text('1 record'), findsOneWidget);
    expect(find.text('Nguyen Van A'), findsOneWidget);
  });
}
