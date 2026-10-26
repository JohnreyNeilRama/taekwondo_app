import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/promotion_record.dart';
import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/screens/promotion_detail_screen.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/backup_service.dart';
import 'package:tkd_app/services/promotion_storage.dart';
import 'package:tkd_app/services/student_storage.dart';

/// Real SQLite only answers on the real event loop, so real time is yielded
/// with [WidgetTester.runAsync] while frames are pumped on the fake clock.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  final StudentStorage students = StudentStorage();
  final PromotionStorage promotions = PromotionStorage();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('storage', () {
    setUp(() async {
      await AppDatabase.debugReset();
      AppDatabase.debugOverridePath = inMemoryDatabasePath;
    });

    tearDown(() async {
      await AppDatabase.debugReset();
    });

    test('promoting keeps the previous belt and its date as history', () async {
      final student = await students.insert(const Student(name: 'Ana Cruz'));
      await promotions.saveForStudent(
        PromotionRecord(
          studentId: student.id!,
          belt: '9th Grade White',
          lastPromotionDate: '01/05/2026',
        ),
      );
      // A first record has nothing before it.
      expect(await promotions.loadHistory(student.id!), isEmpty);

      await promotions.saveForStudent(
        PromotionRecord(
          studentId: student.id!,
          belt: '8th Grade Yellow',
          lastPromotionDate: '06/20/2026',
        ),
      );

      final current = (await promotions.loadRecords()).single;
      expect(current.belt, '8th Grade Yellow');
      expect(current.lastPromotionDate, '06/20/2026');

      final history = await promotions.loadHistory(student.id!);
      expect(history, hasLength(1));
      expect(history.single.belt, '9th Grade White');
      expect(history.single.promotionDate, '01/05/2026');
    });

    test('every promotion adds to the history, the most recent first', () async {
      final student = await students.insert(const Student(name: 'Ana Cruz'));
      Future<void> promote(String belt, String date) => promotions
          .saveForStudent(
            PromotionRecord(
              studentId: student.id!,
              belt: belt,
              lastPromotionDate: date,
            ),
          );
      await promote('9th Grade White', '01/05/2026');
      await promote('8th Grade Yellow', '04/10/2026');
      await promote('7th Grade Yellow', '08/15/2026');

      final history = await promotions.loadHistory(student.id!);
      expect(
        [for (final entry in history) '${entry.belt} ${entry.promotionDate}'],
        ['8th Grade Yellow 04/10/2026', '9th Grade White 01/05/2026'],
      );
      expect((await promotions.loadRecords()).single.belt, '7th Grade Yellow');
    });

    test('correcting the date of the same belt archives nothing', () async {
      final student = await students.insert(const Student(name: 'Ana Cruz'));
      for (final date in ['01/05/2026', '01/06/2026']) {
        await promotions.saveForStudent(
          PromotionRecord(
            studentId: student.id!,
            belt: '9th Grade White',
            lastPromotionDate: date,
          ),
        );
      }
      expect(await promotions.loadHistory(student.id!), isEmpty);
      expect(
        (await promotions.loadRecords()).single.lastPromotionDate,
        '01/06/2026',
      );
    });

    test('a belt saved under its old name is archived under its grade', () async {
      final student = await students.insert(const Student(name: 'Ana Cruz'));
      final db = await AppDatabase.instance.database;
      // A record written before the grade-based curriculum.
      await db.insert('promotions', {
        'student_id': student.id,
        'belt': 'White Belt',
        'last_promotion_date': '01/05/2025',
      });

      // Re-saving the same belt under its new name is not a promotion...
      await promotions.saveForStudent(
        PromotionRecord(
          studentId: student.id!,
          belt: '9th Grade White',
          lastPromotionDate: '01/05/2025',
        ),
      );
      expect(await promotions.loadHistory(student.id!), isEmpty);

      // ...moving on to the next one is.
      await promotions.saveForStudent(
        PromotionRecord(
          studentId: student.id!,
          belt: '8th Grade Yellow',
          lastPromotionDate: '06/01/2026',
        ),
      );
      expect(
        (await promotions.loadHistory(student.id!)).single.belt,
        '9th Grade White',
      );
    });

    test('history comes back with a student restored after a delete', () async {
      final student = await students.insert(const Student(name: 'Ana Cruz'));
      await promotions.saveForStudent(
        PromotionRecord(studentId: student.id!, belt: '9th Grade White'),
      );
      await promotions.saveForStudent(
        PromotionRecord(studentId: student.id!, belt: '8th Grade Yellow'),
      );

      final deleted = await students.delete(student.id!);
      expect(await promotions.loadHistory(student.id!), isEmpty);

      await students.restore(deleted);
      expect(
        (await promotions.loadHistory(student.id!)).single.belt,
        '9th Grade White',
      );
    });

    test('a backup carries the history, and importing it twice adds it once',
        () async {
      final student = await students.insert(const Student(name: 'Ana Cruz'));
      await promotions.saveForStudent(
        PromotionRecord(
          studentId: student.id!,
          belt: '9th Grade White',
          lastPromotionDate: '01/05/2026',
        ),
      );
      await promotions.saveForStudent(
        PromotionRecord(
          studentId: student.id!,
          belt: '8th Grade Yellow',
          lastPromotionDate: '06/20/2026',
        ),
      );
      final backup = BackupService();
      final bytes = await backup.exportBytes();

      // Onto a fresh device.
      await AppDatabase.debugReset();
      AppDatabase.debugOverridePath = inMemoryDatabasePath;
      await backup.importBytes(bytes);
      await backup.importBytes(bytes);

      final restored = (await promotions.loadRecords()).single;
      expect(restored.belt, '8th Grade Yellow');
      final history = await promotions.loadHistory(restored.studentId);
      expect(history, hasLength(1));
      expect(history.single.belt, '9th Grade White');
      expect(history.single.promotionDate, '01/05/2026');
    });
  });

  testWidgets('Promotion Details shows one card per earlier belt', (
    WidgetTester tester,
  ) async {
    late PromotionRecord current;
    await tester.runAsync(() async {
      await AppDatabase.debugReset();
      AppDatabase.debugOverridePath = inMemoryDatabasePath;
      final student = await students.insert(const Student(name: 'Ana Cruz'));
      for (final (belt, date) in [
        ('9th Grade White', '01/05/2026'),
        ('8th Grade Yellow', '04/10/2026'),
        ('7th Grade Yellow', '08/15/2026'),
      ]) {
        await promotions.saveForStudent(
          PromotionRecord(
            studentId: student.id!,
            belt: belt,
            lastPromotionDate: date,
          ),
        );
      }
      current = (await promotions.loadRecords()).single;
    });

    // Tall enough for every card at once: the list builds only what is visible.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: PromotionDetailScreen(record: current)),
    );
    await _settle(tester);

    expect(find.text('PROMOTION HISTORY'), findsOneWidget);
    // Two earlier belts, each on a card of its own.
    expect(find.text('Previous Belt'), findsNWidgets(2));
    expect(find.text('8th Grade Yellow'), findsOneWidget);
    expect(find.text('Promoted 04/10/2026'), findsOneWidget);
    expect(find.text('9th Grade White'), findsOneWidget);
    expect(find.text('Promoted 01/05/2026'), findsOneWidget);
    // The current belt and its date stay at the top.
    expect(find.text('Promoted 08/15/2026'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(AppDatabase.debugReset);
  });
}
