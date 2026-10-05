import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/backup_service.dart';
import 'package:tkd_app/services/student_storage.dart';

/// Starts over with a new, empty in-memory database: the "other device".
Future<void> _freshDatabase() async {
  await AppDatabase.debugReset();
  AppDatabase.debugOverridePath = inMemoryDatabasePath;
}

/// Saves one student straight into the table and returns its id.
Future<int> _addStudent(
  String studentNo,
  String name, {
  String photo = '',
}) async {
  final db = await AppDatabase.instance.database;
  return db.insert('students', {
    'student_no': studentNo,
    'name': name,
    'photo_base64': photo,
  });
}

void main() {
  final backup = BackupService();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(_freshDatabase);

  tearDown(() async {
    await AppDatabase.debugReset();
  });

  test('a backup restores students, belts, awards and pictures', () async {
    final ana = await _addStudent('TKD-0001', 'Ana Cruz', photo: 'AAAA');
    await _addStudent('TKD-0002', 'Ben Reyes');
    final db = await AppDatabase.instance.database;
    await db.insert('promotions', {
      'student_id': ana,
      'belt': 'Yellow Belt',
      'last_promotion_date': '2026-01-10',
    });
    await db.insert('achievements', {
      'student_id': ana,
      'achievement_date': '2026-03-01',
      'event': 'City Open',
      'award': 'Gold',
    });
    final file = await backup.exportBytes();

    await _freshDatabase();
    final result = await backup.importBytes(file);

    expect(result.addedStudents, 2);
    expect(result.addedPromotions, 1);
    expect(result.addedAchievements, 1);
    final counts = await backup.counts();
    expect(counts.students, 2);
    expect(counts.photos, 1);
    expect(counts.promotions, 1);
    expect(counts.achievements, 1);

    final restored = await AppDatabase.instance.database;
    final rows = await restored.rawQuery(
      'SELECT s.student_no, s.name, s.photo_base64, p.belt, a.event, a.award '
      'FROM students s '
      'LEFT JOIN promotions p ON p.student_id = s.id '
      'LEFT JOIN achievements a ON a.student_id = s.id '
      "WHERE s.name = 'Ana Cruz'",
    );
    expect(rows, hasLength(1));
    expect(rows.first['student_no'], 'TKD-0001');
    expect(rows.first['photo_base64'], 'AAAA');
    expect(rows.first['belt'], 'Yellow Belt');
    expect(rows.first['event'], 'City Open');
    expect(rows.first['award'], 'Gold');
  });

  test('importing the same backup twice adds nothing the second time', () async {
    final ana = await _addStudent('TKD-0001', 'Ana Cruz');
    final db = await AppDatabase.instance.database;
    await db.insert('promotions', {
      'student_id': ana,
      'belt': 'Yellow Belt',
      'last_promotion_date': '',
    });
    await db.insert('achievements', {
      'student_id': ana,
      'achievement_date': '2026-03-01',
      'event': 'City Open',
      'award': 'Silver',
    });
    final file = await backup.exportBytes();

    await _freshDatabase();
    await backup.importBytes(file);
    final again = await backup.importBytes(file);

    expect(again.addedNothing, isTrue);
    expect(again.matchedStudents, 1);
    final counts = await backup.counts();
    expect(counts.students, 1);
    expect(counts.promotions, 1);
    expect(counts.achievements, 1);
  });

  test('a number already used here by someone else is replaced', () async {
    await _addStudent('TKD-0001', 'Ben Reyes');
    final file = await backup.exportBytes();

    await _freshDatabase();
    await _addStudent('TKD-0001', 'Ana Cruz');
    final result = await backup.importBytes(file);

    expect(result.addedStudents, 1);
    final db = await AppDatabase.instance.database;
    final rows = await db.query('students', orderBy: 'id');
    expect(rows, hasLength(2));
    expect(rows[0]['name'], 'Ana Cruz');
    expect(rows[0]['student_no'], 'TKD-0001');
    expect(rows[1]['name'], 'Ben Reyes');
    expect(rows[1]['student_no'], isNot('TKD-0001'));
  });

  test('a student added after an import never reuses an imported number', () async {
    await _addStudent('TKD-0007', 'Ana Cruz');
    final file = await backup.exportBytes();

    await _freshDatabase();
    await backup.importBytes(file);
    final db = await AppDatabase.instance.database;
    final next = await db.transaction(
      (txn) => StudentStorage().mintStudentNo(txn),
    );

    expect(next, 'TKD-0008');
  });

  test('an existing belt is never overwritten by an import', () async {
    final ana = await _addStudent('TKD-0001', 'Ana Cruz');
    var db = await AppDatabase.instance.database;
    await db.insert('promotions', {
      'student_id': ana,
      'belt': 'Green Belt',
      'last_promotion_date': '',
    });
    final file = await backup.exportBytes();

    await _freshDatabase();
    final local = await _addStudent('TKD-0001', 'Ana Cruz');
    db = await AppDatabase.instance.database;
    await db.insert('promotions', {
      'student_id': local,
      'belt': 'Blue Belt',
      'last_promotion_date': '',
    });
    await backup.importBytes(file);

    final rows = await db.query('promotions');
    expect(rows, hasLength(1));
    expect(rows.first['belt'], 'Blue Belt');
  });

  test('a file that is not a backup is refused and changes nothing', () async {
    await _addStudent('TKD-0001', 'Ana Cruz');

    expect(
      () => backup.importBytes(Uint8List.fromList(utf8.encode('hello'))),
      throwsA(isA<BackupFormatException>()),
    );
    expect(
      () => backup.importBytes(
        Uint8List.fromList(utf8.encode('{"students": []}')),
      ),
      throwsA(isA<BackupFormatException>()),
    );
    expect((await backup.counts()).students, 1);
  });

  test('a renamed student is not duplicated by a re-import', () async {
    final storage = StudentStorage();
    final saved = await storage.insert(const Student(name: 'Ana Cruz'));
    final file = await backup.exportBytes();

    // The name is corrected on this device after the backup was taken, so the
    // (number + name) pair no longer matches the file.
    await storage.update(Student(id: saved.id, name: 'Ana Santos'));

    final result = await backup.importBytes(file);

    expect(result.addedStudents, 0);
    expect(result.matchedStudents, 1);
    expect((await backup.counts()).students, 1);
  });

  test('a renumbered student is not duplicated by a re-import', () async {
    final storage = StudentStorage();
    final ana = await storage.insert(const Student(name: 'Ana Cruz'));
    await storage.insert(const Student(name: 'Ben Reyes'));
    final file = await backup.exportBytes();

    // A permanent delete packs the numbers back together, so Ben moves from
    // TKD-0002 to TKD-0001 after the backup was taken.
    await storage.moveToTrash(ana.id!);
    await storage.deletePermanently(ana.id!);

    final result = await backup.importBytes(file);

    // Ben is recognised by his identity; only the deleted Ana is brought back.
    expect(result.addedStudents, 1);
    expect(result.matchedStudents, 1);
    expect((await backup.counts()).students, 2);
  });
}
