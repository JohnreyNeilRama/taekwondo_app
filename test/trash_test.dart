import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/services/achievement_storage.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/backup_service.dart';
import 'package:tkd_app/services/promotion_storage.dart';
import 'package:tkd_app/services/student_storage.dart';

/// A student with a picture (both copies), one belt record and two awards: every
/// kind of record the Trash has to keep and give back.
Future<int> _seedStudentWithRecords(StudentStorage storage) async {
  final saved = await storage.insert(
    const Student(
      name: 'Nguyen Van A',
      nickname: 'Van A',
      photoBase64: 'QUJD',
      photoFullBase64: 'QUJDREVG',
    ),
  );
  final id = saved.id!;
  final db = await AppDatabase.instance.database;
  await db.insert('promotions', {
    'student_id': id,
    'belt': '8th Grade Yellow',
    'last_promotion_date': '01/10/2026',
  });
  await db.insert('achievements', {
    'student_id': id,
    'achievement_date': '02/01/2026',
    'event': 'City Open',
    'award': 'Gold',
  });
  await db.insert('achievements', {
    'student_id': id,
    'achievement_date': '03/01/2026',
    'event': 'National Tournament',
    'award': 'Silver',
  });
  return id;
}

Future<int> _count(String table) async {
  final db = await AppDatabase.instance.database;
  final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM $table');
  return rows.first['total'] as int;
}

void main() {
  final StudentStorage storage = StudentStorage();

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

  test('a student in the Trash leaves every list but nothing is deleted', () async {
    final id = await _seedStudentWithRecords(storage);

    await storage.moveToTrash(id);

    expect(await storage.loadStudents(), isEmpty);
    expect(await PromotionStorage().loadRecords(), isEmpty);
    expect(await AchievementStorage().loadRecords(), isEmpty);
    expect((await BackupService().counts()).students, 0);

    // Everything is still saved, waiting in the Trash.
    expect(await _count('students'), 1);
    expect(await _count('promotions'), 1);
    expect(await _count('achievements'), 2);
    final trash = await storage.loadTrash();
    expect(trash, hasLength(1));
    expect(trash.single.student.name, 'Nguyen Van A');
    expect(trash.single.student.studentNo, 'TKD-0001');
    expect(trash.single.student.photoBase64, 'QUJD');
    expect(trash.single.promotionCount, 1);
    expect(trash.single.achievementCount, 2);
    expect(trash.single.deletedAt, isNotNull);
  });

  test('restoring brings back the student with picture, belt and awards', () async {
    final id = await _seedStudentWithRecords(storage);
    await storage.moveToTrash(id);

    await storage.restoreFromTrash(id);

    final students = await storage.loadStudents();
    expect(students, hasLength(1));
    expect(students.single.id, id);
    expect(students.single.studentNo, 'TKD-0001');
    expect(students.single.name, 'Nguyen Van A');
    expect(students.single.photoBase64, 'QUJD');

    final belts = await PromotionStorage().loadRecords();
    expect(belts, hasLength(1));
    expect(belts.single.belt, '8th Grade Yellow');
    expect(belts.single.studentId, id);
    final awards = await AchievementStorage().loadRecords();
    expect(awards, hasLength(2));
    expect([for (final award in awards) award.event], [
      'City Open',
      'National Tournament',
    ]);

    // The original picture was never touched either.
    final db = await AppDatabase.instance.database;
    final row = (await db.query('students')).single;
    expect(row['photo_full_base64'], 'QUJDREVG');
    expect(row['deleted_at'], '');
    expect(await storage.loadTrash(), isEmpty);
  });

  test('deleting permanently removes the student and every related record', () async {
    final id = await _seedStudentWithRecords(storage);
    // A second student, to prove only the right one goes.
    final other = await _seedStudentWithRecords(storage);
    await storage.moveToTrash(id);

    await storage.deletePermanently(id);

    expect(await _count('students'), 1);
    expect(await _count('promotions'), 1);
    expect(await _count('achievements'), 2);
    expect(await storage.loadTrash(), isEmpty);
    final remaining = await storage.loadStudents();
    expect(remaining.single.id, other);
    expect(await AchievementStorage().loadRecords(), hasLength(2));
  });

  test('a student who is not in the Trash cannot be deleted permanently', () async {
    final id = await _seedStudentWithRecords(storage);

    expect(() => storage.deletePermanently(id), throwsA(isA<StateError>()));

    expect(await storage.loadStudents(), hasLength(1));
    expect(await _count('achievements'), 2);
  });

  test('moving to the Trash twice, or restoring a student who is not there, is refused', () async {
    final id = await _seedStudentWithRecords(storage);

    expect(() => storage.restoreFromTrash(id), throwsA(isA<StateError>()));
    await storage.moveToTrash(id);
    expect(() => storage.moveToTrash(id), throwsA(isA<StateError>()));
  });

  test('the number of a student in the Trash is never given to somebody else', () async {
    final id = await _seedStudentWithRecords(storage);
    await storage.moveToTrash(id);

    final next = await storage.insert(const Student(name: 'Tran Thi B'));

    expect(next.studentNo, 'TKD-0002');
  });

  test('the revision counters move, so the open pages refresh', () async {
    final id = await _seedStudentWithRecords(storage);
    final students = StudentStorage.revision;
    final promotions = PromotionStorage.revision;
    final achievements = AchievementStorage.revision;

    await storage.moveToTrash(id);
    expect(StudentStorage.revision, greaterThan(students));
    expect(PromotionStorage.revision, greaterThan(promotions));
    expect(AchievementStorage.revision, greaterThan(achievements));

    final afterTrash = StudentStorage.revision;
    await storage.restoreFromTrash(id);
    expect(StudentStorage.revision, greaterThan(afterTrash));
  });

  test('a permanent delete refreshes every open page', () async {
    final id = await _seedStudentWithRecords(storage);
    await storage.moveToTrash(id);
    final students = StudentStorage.revision;
    final promotions = PromotionStorage.revision;
    final achievements = AchievementStorage.revision;

    // Other students' numbers can change, so every list must read them again.
    await storage.deletePermanently(id);

    expect(StudentStorage.revision, greaterThan(students));
    expect(PromotionStorage.revision, greaterThan(promotions));
    expect(AchievementStorage.revision, greaterThan(achievements));
  });

  test('records stay with their student when a permanent delete moves numbers', () async {
    final first = await _seedStudentWithRecords(storage);
    final second = await _seedStudentWithRecords(storage);
    await storage.moveToTrash(first);

    await storage.deletePermanently(first);

    // The first student's records went with them. The second student's are
    // untouched: still linked by id, and now shown under the number they moved
    // up to.
    expect((await storage.loadStudents()).single.studentNo, 'TKD-0001');
    final belt = (await PromotionStorage().loadRecords()).single;
    expect(belt.studentId, second);
    expect(belt.studentNo, 'TKD-0001');
    expect(belt.belt, '8th Grade Yellow');
    final awards = await AchievementStorage().loadRecords();
    expect(awards, hasLength(2));
    expect(
      awards.every((a) => a.studentId == second && a.studentNo == 'TKD-0001'),
      isTrue,
    );
  });
}
