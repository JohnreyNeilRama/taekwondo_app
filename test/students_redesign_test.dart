import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/screens/students_screen.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/student_storage.dart';
import 'package:tkd_app/widgets/app_nav_bar.dart';

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

/// A phone-shaped screen of the given logical [width], so the layout is checked
/// at the size it has to fit.
void _phone(WidgetTester tester, {required double width, double height = 800}) {
  tester.view.physicalSize = Size(width, height);
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

  group('the student card', () {
    testWidgets('shows the nickname and the school, never the registry or '
        'contact number', (WidgetTester tester) async {
      _phone(tester, width: 400);
      await tester.runAsync(
        () => StudentStorage().insert(
          const Student(
            name: 'Juan Miguel Dela Cruz',
            nickname: 'Johnny',
            schoolName: 'Rizal High School',
            cellphoneNo: '09171234567',
          ),
        ),
      );
      await _openStudents(tester);

      expect(find.text('Dela Cruz, Juan Miguel'), findsOneWidget);
      expect(find.text('"Johnny"'), findsOneWidget);
      expect(find.text('Rizal High School'), findsOneWidget);
      expect(find.text('TKD-0001'), findsNothing);
      expect(find.text('09171234567'), findsNothing);
      // No invented status: the app does not track one.
      expect(find.text('Active'), findsNothing);
    });

    testWidgets('fits a very narrow phone with long text and no overflow', (
      WidgetTester tester,
    ) async {
      _phone(tester, width: 320, height: 640);
      await tester.runAsync(
        () => StudentStorage().insert(
          const Student(
            name: 'Maria Cristina Alexandra Bartolome Dela Cruz-Villanueva',
            nickname: 'Mara-Mara-Mara-Mara-Mara',
            schoolName: 'Our Lady of the Most Holy Rosary Integrated School',
          ),
        ),
      );
      await _openStudents(tester);

      expect(tester.takeException(), isNull);
      // Edit stays reachable, with a touch target of at least 44.
      final edit = find.byTooltip('Edit student');
      expect(edit, findsOneWidget);
      expect(tester.getSize(edit).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(edit).height, greaterThanOrEqualTo(44));
    });

    testWidgets('the three-dot menu opens the QR code', (
      WidgetTester tester,
    ) async {
      _phone(tester, width: 400);
      await tester.runAsync(
        () => StudentStorage().insert(const Student(name: 'Nguyen Van A')),
      );
      await _openStudents(tester);

      await tester.tap(find.byTooltip('More options'));
      await _settle(tester);
      expect(find.text('View details'), findsOneWidget);
      expect(find.text('QR code'), findsOneWidget);
      expect(find.text('Move to Trash'), findsOneWidget);

      await tester.tap(find.text('QR code'));
      await _settle(tester);
      expect(find.text('Student QR code'), findsOneWidget);
    });

    testWidgets('the three-dot menu moves a student to the Trash only after '
        'confirming', (WidgetTester tester) async {
      _phone(tester, width: 400);
      await tester.runAsync(
        () => StudentStorage().insert(const Student(name: 'Nguyen Van A')),
      );
      await _openStudents(tester);
      expect(find.text('1 record'), findsOneWidget);

      // Cancelling keeps the student.
      await tester.tap(find.byTooltip('More options'));
      await _settle(tester);
      await tester.tap(find.text('Move to Trash'));
      await _settle(tester);
      expect(find.text('Delete student?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(find.text('1 record'), findsOneWidget);

      // Confirming moves them to the Trash, with the Undo message.
      await tester.tap(find.byTooltip('More options'));
      await _settle(tester);
      await tester.tap(find.text('Move to Trash'));
      await _settle(tester);
      await tester.tap(find.text('Delete'));
      await _settle(tester);
      expect(find.text('0 records'), findsOneWidget);
      expect(find.text('Nguyen Van A moved to Trash'), findsOneWidget);
      expect(
        (await tester.runAsync(() => StudentStorage().loadTrash()))!,
        hasLength(1),
      );
    });
  });

  group('the page layout', () {
    testWidgets('Add Student sits beside the title on a phone and under it on '
        'a very narrow screen', (WidgetTester tester) async {
      _phone(tester, width: 400);
      await _openStudents(tester);
      final titleY = tester.getCenter(find.text('All Students')).dy;
      final besideY = tester.getCenter(find.text('Add Student').first).dy;
      expect((besideY - titleY).abs(), lessThan(40));

      _phone(tester, width: 320);
      await _openStudents(tester);
      final narrowTitleY = tester.getCenter(find.text('All Students')).dy;
      final narrowAddY = tester.getCenter(find.text('Add Student').first).dy;
      expect(narrowAddY, greaterThan(narrowTitleY + 40));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the sort button orders the list', (WidgetTester tester) async {
      _phone(tester, width: 400);
      await tester.runAsync(() async {
        await StudentStorage().insert(const Student(name: 'Ana Cruz'));
        await StudentStorage().insert(const Student(name: 'Ben Reyes'));
      });
      await _openStudents(tester);

      double top(String text) => tester.getTopLeft(find.text(text)).dy;

      // Family name A-Z is the default.
      expect(top('Cruz, Ana'), lessThan(top('Reyes, Ben')));

      await tester.tap(find.byTooltip('Sort'));
      await _settle(tester);
      expect(find.text('Sort students'), findsOneWidget);
      await tester.tap(find.text('Name Z\u2013A'));
      await _settle(tester);

      expect(top('Reyes, Ben'), lessThan(top('Cruz, Ana')));
      expect(find.text('2 records \u00B7 Name Z\u2013A'), findsOneWidget);

      // Recently added puts the student added last on top: Ben, here.
      await tester.tap(find.byTooltip('Sort'));
      await _settle(tester);
      await tester.tap(find.text('Recently added'));
      await _settle(tester);
      expect(top('Reyes, Ben'), lessThan(top('Cruz, Ana')));

      // Back to the default: the label goes and the order returns.
      await tester.tap(find.byTooltip('Sort'));
      await _settle(tester);
      await tester.tap(find.text('Name A\u2013Z'));
      await _settle(tester);
      expect(find.text('2 records'), findsOneWidget);
      expect(top('Cruz, Ana'), lessThan(top('Reyes, Ben')));
    });

    testWidgets('a search with no match offers to clear it', (
      WidgetTester tester,
    ) async {
      _phone(tester, width: 400);
      await tester.runAsync(
        () => StudentStorage().insert(const Student(name: 'Ana Cruz')),
      );
      await _openStudents(tester);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('No student records found.'), findsOneWidget);
      expect(find.text('0 results for "zzz"'), findsOneWidget);

      await tester.tap(find.text('Clear search'));
      await tester.pump();
      expect(find.text('Cruz, Ana'), findsOneWidget);
      expect(find.text('1 record'), findsOneWidget);
    });
  });

  group('the bottom bar', () {
    Widget bar({
      required ValueChanged<int> onSelected,
      bool badge = false,
      int selected = 0,
    }) {
      return MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppNavBar(
            selected: selected,
            onSelected: onSelected,
            showDataBadge: badge,
          ),
        ),
      );
    }

    testWidgets('fits the narrowest phone and reports the slot that was tapped', (
      WidgetTester tester,
    ) async {
      _phone(tester, width: 320, height: 640);
      final taps = <int>[];
      await tester.pumpWidget(bar(onSelected: taps.add));

      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Promotion'));
      await tester.tap(find.text('Scan'));
      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.tap(find.text('Achievement'));
      await tester.tap(find.text('Data'));
      expect(taps, [1, 2, 2, 3, 4]);
    });

    testWidgets('the Scan button rises above the rest of the bar', (
      WidgetTester tester,
    ) async {
      _phone(tester, width: 400);
      await tester.pumpWidget(bar(onSelected: (_) {}));

      final scanTop = tester.getTopLeft(find.byIcon(Icons.qr_code_scanner)).dy;
      final studentsTop = tester.getTopLeft(find.byIcon(Icons.groups)).dy;
      expect(scanTop, lessThan(studentsTop));
    });

    testWidgets('the red dot shows on Data only while a backup is due', (
      WidgetTester tester,
    ) async {
      _phone(tester, width: 400);
      await tester.pumpWidget(bar(onSelected: (_) {}));
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);

      await tester.pumpWidget(bar(onSelected: (_) {}, badge: true));
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
    });
  });
}
