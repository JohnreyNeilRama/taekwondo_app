import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/achievement_record.dart';
import 'package:tkd_app/models/promotion_record.dart';
import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/services/achievement_storage.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/promotion_storage.dart';
import 'package:tkd_app/services/student_storage.dart';

void main() {
  final StudentStorage students = StudentStorage();
  final PromotionStorage promotions = PromotionStorage();
  final AchievementStorage achievements = AchievementStorage();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Every test starts from its own empty in-memory database, so the records
    // on the device are never read or written.
    await AppDatabase.debugReset();
    AppDatabase.debugOverridePath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await AppDatabase.debugReset();
  });

  /// Saves one student and returns the row as it was stored, registry number
  /// and id included.
  Future<Student> seedStudent([String name = 'Nguyen Van A']) =>
      students.insert(Student(name: name));

  test(
    'a student holds one promotion, read back with their current name',
    () async {
      final student = await seedStudent();

      final first = await promotions.saveForStudent(
        PromotionRecord(
          studentId: student.id!,
          belt: '8th Grade Yellow',
          lastPromotionDate: '03/10/2026',
        ),
      );
      final reloaded = (await promotions.loadRecords()).single;
      expect(reloaded.id, first.id);
      expect(reloaded.studentId, student.id);
      // The registry number and the name come from the students table, not from
      // a copy saved on the record.
      expect(reloaded.studentNo, student.studentNo);
      expect(reloaded.studentName, 'Nguyen Van A');
      expect(reloaded.belt, '8th Grade Yellow');
      expect(reloaded.lastPromotionDate, '03/10/2026');

      // Saving that student again replaces their record instead of adding a
      // second belt.
      await promotions.saveForStudent(
        PromotionRecord(
          studentId: student.id!,
          belt: '4th Grade Red',
          lastPromotionDate: '04/11/2026',
        ),
      );
      final updated = (await promotions.loadRecords()).single;
      expect(updated.id, first.id);
      expect(updated.belt, '4th Grade Red');
      expect(updated.lastPromotionDate, '04/11/2026');
    },
  );

  test('a renamed student shows their new name on both lists', () async {
    final student = await seedStudent();
    await promotions.saveForStudent(
      PromotionRecord(studentId: student.id!, belt: '9th Grade White'),
    );
    await achievements.insert(
      AchievementRecord(
        studentId: student.id!,
        event: 'Regionals',
        award: 'Gold',
      ),
    );

    // update() writes every column, so the renamed record carries the id and
    // the registry number it already had.
    await students.update(
      Student(
        id: student.id,
        studentNo: student.studentNo,
        name: 'Nguyen Van B',
      ),
    );

    expect((await promotions.loadRecords()).single.studentName, 'Nguyen Van B');
    expect(
      (await achievements.loadRecords()).single.studentName,
      'Nguyen Van B',
    );
  });

  test('records for a student who does not exist are rejected', () async {
    expect(
      () => promotions.saveForStudent(
        PromotionRecord(studentId: 999, belt: '9th Grade White'),
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect(
      () => achievements.insert(
        AchievementRecord(studentId: 999, event: 'Ghost event', award: 'Gold'),
      ),
      throwsA(isA<DatabaseException>()),
    );

    expect(await promotions.loadRecords(), isEmpty);
    expect(await achievements.loadRecords(), isEmpty);
  });

  test(
    'many achievements per student, each edited and deleted on its own',
    () async {
      final student = await seedStudent();
      final gold = await achievements.insert(
        AchievementRecord(
          studentId: student.id!,
          date: '01/02/2026',
          event: 'Regionals',
          award: 'Gold',
        ),
      );
      final silver = await achievements.insert(
        AchievementRecord(
          studentId: student.id!,
          date: '02/03/2026',
          event: 'Nationals',
          award: 'Silver',
        ),
      );
      final bronze = await achievements.insert(
        AchievementRecord(
          studentId: student.id!,
          date: '03/04/2026',
          event: 'Invitationals',
          award: 'Bronze',
        ),
      );

      var saved = await achievements.loadRecords();
      expect(
        [for (final record in saved) record.award],
        ['Gold', 'Silver', 'Bronze'],
      );
      expect(saved.every((record) => record.studentId == student.id), isTrue);
      expect(await achievements.loadForStudent(student.id!), hasLength(3));

      // Changing one award leaves the other two exactly as they were.
      await achievements.update(
        gold.copyWith(event: 'Nationals', award: 'Bronze'),
      );
      saved = await achievements.loadRecords();
      expect(
        [for (final record in saved) record.id],
        [gold.id, silver.id, bronze.id],
      );
      expect(saved[0].event, 'Nationals');
      expect(saved[0].award, 'Bronze');
      expect(saved[1].award, 'Silver');
      expect(saved[2].award, 'Bronze');

      // Deleting one leaves the rest of the student's awards in place.
      await achievements.delete(bronze.id!);
      saved = await achievements.loadRecords();
      expect([for (final record in saved) record.id], [gold.id, silver.id]);
      expect(await achievements.loadForStudent(student.id!), hasLength(2));
    },
  );

  test('an award outside Gold, Silver and Bronze is rejected', () async {
    final student = await seedStudent();

    expect(
      () => achievements.insert(
        AchievementRecord(
          studentId: student.id!,
          event: 'Regionals',
          award: 'Platinum',
        ),
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect(await achievements.loadRecords(), isEmpty);
  });

  test('an achievement that was never saved cannot be updated', () async {
    final student = await seedStudent();
    expect(
      () => achievements.update(
        AchievementRecord(studentId: student.id!, event: 'Regionals'),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('deleting a student takes their promotion and achievements with them', () async {
    final student = await seedStudent();
    await promotions.saveForStudent(
      PromotionRecord(studentId: student.id!, belt: '8th Grade Yellow'),
    );
    await achievements.insert(
      AchievementRecord(
        studentId: student.id!,
        event: 'Regionals',
        award: 'Gold',
      ),
    );

    await students.delete(student.id!);

    // The foreign keys cascade, so no record is left pointing at a student who
    // is no longer in the registry.
    expect(await students.loadStudents(), isEmpty);
    expect(await promotions.loadRecords(), isEmpty);
    expect(await achievements.loadRecords(), isEmpty);
  });

  test('the Undo snapshot brings the student and both records back', () async {
    final student = await seedStudent();
    final promotion = await promotions.saveForStudent(
      PromotionRecord(
        studentId: student.id!,
        belt: '8th Grade Yellow',
        lastPromotionDate: '03/10/2026',
      ),
    );
    final gold = await achievements.insert(
      AchievementRecord(
        studentId: student.id!,
        date: '01/02/2026',
        event: 'Regionals',
        award: 'Gold',
      ),
    );
    final bronze = await achievements.insert(
      AchievementRecord(
        studentId: student.id!,
        date: '02/03/2026',
        event: 'Nationals',
        award: 'Bronze',
      ),
    );

    // The snapshot is taken before the row goes, which is the only way to put
    // the cascaded records back.
    final deleted = await students.delete(student.id!);
    await students.restore(deleted);

    final restored = (await students.loadStudents()).single;
    expect(restored.id, student.id);
    expect(restored.studentNo, 'TKD-0001');

    final restoredPromotion = (await promotions.loadRecords()).single;
    expect(restoredPromotion.id, promotion.id);
    expect(restoredPromotion.studentId, student.id);
    expect(restoredPromotion.belt, '8th Grade Yellow');
    expect(restoredPromotion.lastPromotionDate, '03/10/2026');

    final restoredAchievements = await achievements.loadRecords();
    expect(
      [for (final record in restoredAchievements) record.id],
      [gold.id, bronze.id],
    );
    expect(
      [for (final record in restoredAchievements) record.award],
      ['Gold', 'Bronze'],
    );
  });
}
