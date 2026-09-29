import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/services/achievement_storage.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/legacy_json_import.dart';
import 'package:tkd_app/services/promotion_storage.dart';
import 'package:tkd_app/services/student_storage.dart';

void main() {
  final StudentStorage students = StudentStorage();
  final PromotionStorage promotions = PromotionStorage();
  final AchievementStorage achievements = AchievementStorage();

  late Directory folder;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.debugReset();
    AppDatabase.debugOverridePath = inMemoryDatabasePath;
    // The legacy files are read from a throwaway folder, never from the real
    // `%APPDATA%\tkd_app`, so the owner's data is never touched by a test.
    folder = await Directory.systemTemp.createTemp('tkd_app_import_test');
    LegacyJsonImporter.debugOverrideDirectory = folder;
  });

  tearDown(() async {
    LegacyJsonImporter.debugOverrideDirectory = null;
    await AppDatabase.debugReset();
    try {
      if (folder.existsSync()) await folder.delete(recursive: true);
    } catch (_) {
      // A failed cleanup must not fail a test.
    }
  });

  /// Writes one legacy JSON file the way the old file-based storage did.
  Future<File> writeLegacy(String fileName, Object contents) {
    final file = File('${folder.path}${Platform.pathSeparator}$fileName');
    return file.writeAsString(jsonEncode(contents));
  }

  test('the JSON files are imported once, linked by registry number', () async {
    await writeLegacy('students_v1.json', [
      {'name': 'Nguyen Van A', 'studentNo': 'TKD-0001', 'nickname': 'Van A'},
      {'name': 'Tran Thi B', 'studentNo': 'TKD-0002', 'sex': 'Female'},
    ]);
    await writeLegacy('promotions_v1.json', [
      {
        'studentNo': 'TKD-0002',
        'belt': 'Yellow Belt',
        'lastPromotionDate': '03/10/2026',
      },
      // A record whose student is not in the file.
      {'studentNo': 'TKD-9999', 'belt': 'Red Belt'},
    ]);
    await writeLegacy('achievements_v1.json', [
      {
        'studentNo': 'TKD-0001',
        'date': '01/02/2026',
        'event': 'Regionals',
        'award': 'Gold',
      },
      {
        'studentNo': 'TKD-9999',
        'date': '01/02/2026',
        'event': 'Ghost event',
        'award': 'Gold',
      },
      {
        'studentNo': 'TKD-0001',
        'date': '02/03/2026',
        'event': 'Nationals',
        'award': 'Platinum',
      },
    ]);

    expect(await LegacyJsonImporter().importIfNeeded(), 2);

    final saved = await students.loadStudents();
    expect(
      [for (final student in saved) student.studentNo],
      ['TKD-0001', 'TKD-0002'],
    );
    expect(saved[0].name, 'Nguyen Van A');
    expect(saved[0].nickname, 'Van A');
    expect(saved[1].name, 'Tran Thi B');
    expect(saved[1].sex, 'Female');

    // The promotion points at the id of TKD-0002 — the id, not a copy of the
    // student — and the pre-grade belt name has been mapped onto the grade that
    // replaced it.
    final promotion = (await promotions.loadRecords()).single;
    expect(promotion.studentId, saved[1].id);
    expect(promotion.studentNo, 'TKD-0002');
    expect(promotion.studentName, 'Tran Thi B');
    expect(promotion.belt, '8th Grade Yellow');
    expect(promotion.lastPromotionDate, '03/10/2026');

    // Only the achievement whose student exists and whose award the table
    // accepts was brought across.
    final award = (await achievements.loadRecords()).single;
    expect(award.studentId, saved[0].id);
    expect(award.studentNo, 'TKD-0001');
    expect(award.date, '01/02/2026');
    expect(award.event, 'Regionals');
    expect(award.award, 'Gold');
  });

  test('a second import does nothing', () async {
    await writeLegacy('students_v1.json', [
      {'name': 'Nguyen Van A', 'studentNo': 'TKD-0001'},
    ]);
    await writeLegacy('achievements_v1.json', [
      {'studentNo': 'TKD-0001', 'event': 'Regionals', 'award': 'Gold'},
    ]);

    expect(await LegacyJsonImporter().importIfNeeded(), 1);
    // The registry is no longer empty, so the files are ignored from here on.
    expect(await LegacyJsonImporter().importIfNeeded(), 0);

    expect(await students.loadStudents(), hasLength(1));
    expect(await achievements.loadRecords(), hasLength(1));
  });

  test('a registry that already has students is left alone', () async {
    final student = await students.insert(const Student(name: 'Saved later'));
    await writeLegacy('students_v1.json', [
      {'name': 'Nguyen Van A', 'studentNo': 'TKD-0001'},
    ]);

    expect(await LegacyJsonImporter().importIfNeeded(), 0);

    final saved = await students.loadStudents();
    expect(saved, hasLength(1));
    expect(saved.single.name, 'Saved later');
    expect(saved.single.id, student.id);
  });

  test('missing or unreadable files never crash the start', () async {
    // Nothing in the folder at all, which is also what happens on a phone.
    expect(await LegacyJsonImporter().importIfNeeded(), 0);
    expect(await students.loadStudents(), isEmpty);

    // A file holding something other than a list of records.
    await writeLegacy('students_v1.json', {'not': 'a list'});
    expect(await LegacyJsonImporter().importIfNeeded(), 0);

    // A file that is not JSON at all.
    final broken = File(
      '${folder.path}${Platform.pathSeparator}students_v1.json',
    );
    await broken.writeAsString('{ this is not json');
    expect(await LegacyJsonImporter().importIfNeeded(), 0);

    expect(await students.loadStudents(), isEmpty);
  });

  test('the JSON files are never changed by the import', () async {
    final file = await writeLegacy('students_v1.json', [
      {'name': 'Nguyen Van A', 'studentNo': 'TKD-0001'},
    ]);
    final before = await file.readAsString();

    await LegacyJsonImporter().importIfNeeded();

    expect(await file.exists(), isTrue);
    expect(await file.readAsString(), before);
  });
}
