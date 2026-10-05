import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/attendance_storage.dart';
import 'package:tkd_app/services/backup_service.dart';
import 'package:tkd_app/services/student_storage.dart';

/// Starts over with a new, empty in-memory database: the "other device".
Future<void> _freshDatabase() async {
  await AppDatabase.debugReset();
  AppDatabase.debugOverridePath = inMemoryDatabasePath;
}

Future<int> _addStudent(String studentNo, String name) async {
  final db = await AppDatabase.instance.database;
  return db.insert('students', {'student_no': studentNo, 'name': name});
}

Future<void> _addCheckIn(int studentId, String day, String at) async {
  final db = await AppDatabase.instance.database;
  await db.insert('attendance', {
    'student_id': studentId,
    'attended_on': day,
    'checked_in_at': at,
  });
}

/// The check-ins saved for the student called [name], oldest day first.
Future<List<Map<String, Object?>>> _attendanceFor(String name) async {
  final db = await AppDatabase.instance.database;
  return db.rawQuery(
    'SELECT a.attended_on, a.checked_in_at FROM attendance a '
    'JOIN students s ON s.id = a.student_id '
    'WHERE s.name = ? ORDER BY a.attended_on',
    [name],
  );
}

Future<int> _attendanceRows() async {
  final db = await AppDatabase.instance.database;
  final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM attendance');
  return rows.first['total'] as int;
}

Map<String, Object?> _decode(Uint8List bytes) =>
    Map<String, Object?>.from(jsonDecode(utf8.decode(bytes)) as Map);

Uint8List _encode(Map<String, Object?> document) =>
    Uint8List.fromList(utf8.encode(jsonEncode(document)));

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

  test('a backup holds the attendance and restores it', () async {
    final ana = await _addStudent('TKD-0001', 'Ana Cruz');
    await _addCheckIn(ana, '2026-10-06', '2026-10-06T09:30:00.000');
    await _addCheckIn(ana, '2026-10-07', '2026-10-07T18:05:00.000');
    final file = await backup.exportBytes();

    expect(_decode(file)['attendance'], isA<List>().having(
      (rows) => rows.length,
      'length',
      2,
    ));

    await _freshDatabase();
    final before = AttendanceStorage.revision;
    final result = await backup.importBytes(file);

    expect(result.addedStudents, 1);
    expect(result.addedAttendance, 2);
    expect(result.addedNothing, isFalse);
    expect((await backup.counts()).attendance, 2);
    expect(await _attendanceFor('Ana Cruz'), [
      {'attended_on': '2026-10-06', 'checked_in_at': '2026-10-06T09:30:00.000'},
      {'attended_on': '2026-10-07', 'checked_in_at': '2026-10-07T18:05:00.000'},
    ]);
    // The Attendance page re-reads when this number changes.
    expect(AttendanceStorage.revision, greaterThan(before));
  });

  test('importing the same backup twice adds no attendance the second time',
      () async {
    final ana = await _addStudent('TKD-0001', 'Ana Cruz');
    await _addCheckIn(ana, '2026-10-06', '2026-10-06T09:30:00.000');
    final file = await backup.exportBytes();

    await _freshDatabase();
    await backup.importBytes(file);
    final again = await backup.importBytes(file);

    expect(again.addedAttendance, 0);
    expect(again.addedNothing, isTrue);
    expect(await _attendanceRows(), 1);
  });

  test('a day already recorded here keeps its time; only new days are added',
      () async {
    final source = await _addStudent('TKD-0001', 'Ana Cruz');
    await _addCheckIn(source, '2026-10-06', '2026-10-06T09:00:00.000');
    await _addCheckIn(source, '2026-10-07', '2026-10-07T09:00:00.000');
    final file = await backup.exportBytes();

    await _freshDatabase();
    final local = await _addStudent('TKD-0001', 'Ana Cruz');
    await _addCheckIn(local, '2026-10-06', '2026-10-06T18:30:00.000');
    final result = await backup.importBytes(file);

    expect(result.addedStudents, 0);
    expect(result.matchedStudents, 1);
    expect(result.addedAttendance, 1);
    expect(await _attendanceFor('Ana Cruz'), [
      {'attended_on': '2026-10-06', 'checked_in_at': '2026-10-06T18:30:00.000'},
      {'attended_on': '2026-10-07', 'checked_in_at': '2026-10-07T09:00:00.000'},
    ]);
  });

  test('a backup made before attendance existed still imports', () async {
    final ana = await _addStudent('TKD-0001', 'Ana Cruz');
    await _addCheckIn(ana, '2026-10-06', '2026-10-06T09:30:00.000');
    final old = _decode(await backup.exportBytes())..remove('attendance');

    await _freshDatabase();
    final result = await backup.importBytes(_encode(old));

    expect(result.addedStudents, 1);
    expect(result.addedAttendance, 0);
    expect(await _attendanceRows(), 0);
  });

  test('attendance rows that cannot be used are skipped, the rest are kept',
      () async {
    final ana = await _addStudent('TKD-0001', 'Ana Cruz');
    final document = _decode(await backup.exportBytes());
    document['attendance'] = [
      {
        'id': 1,
        'student_id': ana,
        'attended_on': '2026-10-06',
        'checked_in_at': '2026-10-06T09:00:00.000',
      },
      // Not a yyyy-mm-dd day.
      {
        'id': 2,
        'student_id': ana,
        'attended_on': 'yesterday',
        'checked_in_at': '2026-10-05T09:00:00.000',
      },
      // A student the file does not hold.
      {
        'id': 3,
        'student_id': 999,
        'attended_on': '2026-10-07',
        'checked_in_at': '2026-10-07T09:00:00.000',
      },
      // The same day twice in the file counts once.
      {
        'id': 4,
        'student_id': ana,
        'attended_on': '2026-10-06',
        'checked_in_at': '2026-10-06T10:00:00.000',
      },
    ];

    await _freshDatabase();
    final result = await backup.importBytes(_encode(document));

    expect(result.addedAttendance, 1);
    expect(result.skipped, 2);
    expect(await _attendanceFor('Ana Cruz'), [
      {'attended_on': '2026-10-06', 'checked_in_at': '2026-10-06T09:00:00.000'},
    ]);
  });

  test('attendance follows a student who was renamed after the backup',
      () async {
    final storage = StudentStorage();
    final saved = await storage.insert(const Student(name: 'Ana Cruz'));
    await AttendanceStorage().checkIn(
      saved,
      now: DateTime(2026, 10, 6, 9, 30),
    );
    final file = await backup.exportBytes();

    // On this device the check-in is gone and the student has been renamed.
    final db = await AppDatabase.instance.database;
    await db.delete('attendance');
    await storage.update(Student(id: saved.id, name: 'Ana Santos'));

    final result = await backup.importBytes(file);

    expect(result.addedStudents, 0);
    expect(result.matchedStudents, 1);
    expect(result.addedAttendance, 1);
    expect(await _attendanceFor('Ana Santos'), hasLength(1));
    expect((await backup.counts()).students, 1);
  });

  test('a student in the Trash keeps their attendance through a backup',
      () async {
    final storage = StudentStorage();
    final saved = await storage.insert(const Student(name: 'Ana Cruz'));
    await AttendanceStorage().checkIn(
      saved,
      now: DateTime(2026, 10, 6, 9, 30),
    );
    await storage.moveToTrash(saved.id!);
    final file = await backup.exportBytes();

    await _freshDatabase();
    final result = await backup.importBytes(file);

    expect(result.addedStudents, 1);
    expect(result.addedAttendance, 1);
    // Still in the Trash, so it is not counted or listed...
    expect((await backup.counts()).attendance, 0);
    // ...but it is saved, and comes back when the student is restored.
    expect(await _attendanceRows(), 1);
    final db = await AppDatabase.instance.database;
    final restoredId =
        (await db.query('students', columns: ['id'])).first['id'] as int;
    await StudentStorage().restoreFromTrash(restoredId);
    expect((await backup.counts()).attendance, 1);
  });
}
