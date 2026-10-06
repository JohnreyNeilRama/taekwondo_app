import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/services/app_database.dart';

/// The tables the v1 schema creates.
const List<String> _schemaTables = ['students', 'promotions', 'achievements'];

void main() {
  setUpAll(() {
    // Flutter's own platform channels are not running in a test, so the app's
    // SQLite database is opened through the FFI implementation instead.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Every test starts from its own empty in-memory database, so no test can
    // see another one's records and the registry on the device is never touched.
    await AppDatabase.debugReset();
    AppDatabase.debugOverridePath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await AppDatabase.debugReset();
  });

  test('the database is created with the three record tables', () async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ?',
      whereArgs: ['table'],
    );
    final names = [for (final row in rows) row['name'] as String];
    for (final table in _schemaTables) {
      expect(names, contains(table), reason: '$table should exist');
    }
  });

  test(
    'students holds the id, the registry number and the name first',
    () async {
      final db = await AppDatabase.instance.database;
      final columns = await db.rawQuery('PRAGMA table_info(students)');
      final names = [for (final column in columns) column['name'] as String];

      expect(names.first, 'id');
      expect(names[1], 'student_no');
      expect(names[2], 'name');
      // The three above plus the 25 remaining sheet columns, the two photo
      // columns (the compact copy and the original), the Trash mark, the
      // stable identity and the enrolment time.
      expect(names, hasLength(33));
      expect(names, contains('uid'));
      expect(names, contains('created_at'));
    },
  );

  test('the contact columns take a number of any shape, so no table change is '
      'needed', () async {
    final db = await AppDatabase.instance.database;
    final columns = await db.rawQuery('PRAGMA table_info(students)');
    final byName = {
      for (final column in columns) column['name'] as String: column,
    };

    for (final name in ['telephone_nos', 'cellphone_no']) {
      // Plain text with no length limit and no format rule: the 11-digit
      // cellphone and the laid-out 10-digit telephone both fit exactly as they
      // are, and a number saved in any older shape is never refused by the
      // table. Nothing here needs a migration.
      expect(byName[name]?['type'], 'TEXT', reason: '$name should be TEXT');
      expect(byName[name]?['notnull'], 1, reason: '$name should be NOT NULL');
    }
  });

  test('promotions allows one record per student', () async {
    final db = await AppDatabase.instance.database;
    final columns = await db.rawQuery('PRAGMA table_info(promotions)');
    final names = [for (final column in columns) column['name'] as String];
    expect(names, ['id', 'student_id', 'belt', 'last_promotion_date']);

    // The UNIQUE constraint on student_id is what keeps one promotion per
    // student, whatever the screens do.
    final create = await db.rawQuery(
      "SELECT sql FROM sqlite_master WHERE name = 'promotions'",
    );
    expect(create.first['sql'] as String, contains('UNIQUE'));
  });

  test('achievements keeps a date, an event and a medal', () async {
    final db = await AppDatabase.instance.database;
    final columns = await db.rawQuery('PRAGMA table_info(achievements)');
    final names = [for (final column in columns) column['name'] as String];
    expect(names, ['id', 'student_id', 'achievement_date', 'event', 'award']);

    // The index on student_id is what makes the per-student list fast.
    final indexes = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    );
    final indexNames = [for (final row in indexes) row['name'] as String];
    expect(indexNames, contains('idx_achievements_student_id'));
  });

  test('foreign keys are switched on for every connection', () async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('PRAGMA foreign_keys');
    expect(rows.first.values.first, 1);
  });

  test('upgrading a version 5 database adds created_at and fills it in',
      () async {
    final folder = await Directory.systemTemp.createTemp('tkd_app_v6_test');
    addTearDown(() async {
      // The file has to be closed before its folder can be removed.
      await AppDatabase.debugReset();
      try {
        await folder.delete(recursive: true);
      } catch (_) {
        // A failed cleanup must not fail a test.
      }
    });
    final path = p.join(folder.path, 'tkd_app.db');

    // A database as version 5 left it: students and attendance, and no
    // created_at column yet. Only the columns the upgrade touches are needed.
    final old = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5,
        onCreate: (db, _) async {
          await db.execute('''
CREATE TABLE students (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  student_no TEXT NOT NULL UNIQUE,
  name       TEXT NOT NULL,
  deleted_at TEXT NOT NULL DEFAULT '',
  uid        TEXT NOT NULL DEFAULT ''
)
''');
          await db.execute('''
CREATE TABLE attendance (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id    INTEGER NOT NULL,
  attended_on   TEXT    NOT NULL,
  checked_in_at TEXT    NOT NULL,
  UNIQUE (student_id, attended_on)
)
''');
        },
      ),
    );
    final anaId = await old.insert('students', {
      'student_no': 'TKD-0001',
      'name': 'Ana Cruz',
    });
    await old.insert('students', {'student_no': 'TKD-0002', 'name': 'Ben Reyes'});
    // Written out of order: the estimate is the earliest day, not the first row.
    for (final day in ['2026-10-06', '2026-10-02']) {
      await old.insert('attendance', {
        'student_id': anaId,
        'attended_on': day,
        'checked_in_at': '${day}T09:30:00.000',
      });
    }
    await old.close();

    final before = DateTime.now();
    await AppDatabase.debugReset();
    AppDatabase.debugOverridePath = path;
    final db = await AppDatabase.instance.database;

    final columns = await db.rawQuery('PRAGMA table_info(students)');
    expect([for (final c in columns) c['name']], contains('created_at'));

    final rows = await db.query('students', orderBy: 'id');
    // Ana was certainly enrolled by her first check-in.
    expect(rows[0]['created_at'], '2026-10-02T00:00:00.000');
    // Ben never checked in, so his absences are counted from the upgrade on.
    final ben = DateTime.tryParse(rows[1]['created_at'] as String? ?? '');
    expect(ben, isNotNull);
    expect(ben!.isBefore(before.subtract(const Duration(seconds: 1))), isFalse);
    expect(ben.isAfter(DateTime.now().add(const Duration(seconds: 1))), isFalse);

    // Running the backfill again changes nothing: a date that is there stays.
    await AppDatabase.backfillCreatedAt(db, now: DateTime(2030, 1, 1));
    final again = await db.query('students', orderBy: 'id');
    expect(again[0]['created_at'], rows[0]['created_at']);
    expect(again[1]['created_at'], rows[1]['created_at']);
  });
}
