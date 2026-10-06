import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'achievement_storage.dart';
import 'attendance_storage.dart';
import 'class_schedule.dart';
import 'promotion_storage.dart';
import 'student_storage.dart';
import 'student_uid.dart';

/// Thrown when a file picked for import is not a backup this app can read. The
/// [message] is written for the owner and is shown as it is.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// How much is saved on this device, for the summary at the top of the Data
/// page.
class BackupCounts {
  const BackupCounts({
    required this.students,
    required this.photos,
    required this.promotions,
    required this.achievements,
    this.attendance = 0,
  });

  final int students;
  final int photos;
  final int promotions;
  final int achievements;

  /// Check-ins recorded by scanning a student's QR code.
  final int attendance;
}

/// What an import did.
class ImportResult {
  const ImportResult({
    required this.addedStudents,
    required this.matchedStudents,
    required this.addedPromotions,
    required this.addedAchievements,
    required this.skipped,
    this.addedAttendance = 0,
  });

  /// Students that were not on this device and have been added.
  final int addedStudents;

  /// Students of the backup that were already here (same registry number and
  /// name), so nothing was added for them.
  final int matchedStudents;

  final int addedPromotions;
  final int addedAchievements;

  /// Check-ins that were not on this device and have been added.
  final int addedAttendance;

  /// Rows of the file that could not be used (no name, an unknown medal, a
  /// record pointing at a student the file does not hold).
  final int skipped;

  bool get addedNothing =>
      addedStudents == 0 &&
      addedPromotions == 0 &&
      addedAchievements == 0 &&
      addedAttendance == 0;
}

/// Above this size a backup is encoded or decoded on a background isolate, so
/// a registry full of photos does not freeze the screen while it is worked on.
/// Small files stay on the calling isolate, where nothing is noticeable.
const int _backgroundThreshold = 1024 * 1024;

/// Isolate entry point: the backup document as UTF-8 JSON bytes.
Uint8List _encodeBackup(Map<String, Object?> document) =>
    Uint8List.fromList(utf8.encode(jsonEncode(document)));

/// Isolate entry point: the decoded backup, or null when the bytes are not JSON.
Object? _decodeBackup(Uint8List bytes) {
  try {
    return jsonDecode(utf8.decode(bytes));
  } on FormatException {
    return null;
  }
}

/// Exports the whole registry to one file and merges such a file back in.
///
/// The backup is a single JSON document holding every row of the `students`,
/// `promotions`, `achievements` and `attendance` tables, pictures included.
/// It is written
/// from one read transaction, so it is a consistent snapshot even if the app is
/// used while it is being made.
///
/// Importing only ever adds: an existing record is never changed or deleted,
/// which is what makes importing the wrong file, or the same file twice, safe.
class BackupService {
  static const String formatName = 'tkd_app_backup';
  static const int formatVersion = 1;

  static const Set<String> _awards = {'Gold', 'Silver', 'Bronze'};
  static const Set<String> _sexes = {'', 'Male', 'Female'};

  /// The `yyyy-mm-dd` shape of an attendance day.
  static final RegExp _dayPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Key the moment of the last successful export is kept under, in `app_meta`.
  /// The `backup.` prefix keeps it clear of the `security.` counters, and
  /// nothing under either prefix is ever written into a backup file.
  static const String lastExportKey = 'backup.last_export_at';

  /// How long a registry that holds records may go without a fresh backup
  /// before the app starts reminding the owner to export one.
  static const Duration reminderAfter = Duration(days: 7);

  final StudentStorage _students = StudentStorage();

  /// The file name offered in the save dialog, e.g. `tkd_backup_2026-09-30.json`.
  static String suggestedFileName([DateTime? now]) {
    final date = now ?? DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'tkd_backup_${date.year}-${two(date.month)}-${two(date.day)}.json';
  }

  /// The numbers shown on the Data page.
  Future<BackupCounts> counts() async {
    final db = await AppDatabase.instance.database;
    Future<int> count(String sql) async =>
        Sqflite.firstIntValue(await db.rawQuery(sql)) ?? 0;
    return BackupCounts(
      students: await count("SELECT COUNT(*) FROM students WHERE deleted_at = ''"),
      photos: await count(
        "SELECT COUNT(*) FROM students WHERE deleted_at = '' "
        "AND (photo_base64 <> '' OR photo_full_base64 <> '')",
      ),
      promotions: await count(
        'SELECT COUNT(*) FROM promotions p '
        "JOIN students s ON s.id = p.student_id AND s.deleted_at = ''",
      ),
      achievements: await count(
        'SELECT COUNT(*) FROM achievements a '
        "JOIN students s ON s.id = a.student_id AND s.deleted_at = ''",
      ),
      attendance: await count(
        'SELECT COUNT(*) FROM attendance a '
        "JOIN students s ON s.id = a.student_id AND s.deleted_at = ''",
      ),
    );
  }

  /// Records that a backup was just saved to a file, so the reminder can start
  /// counting again. Called by the Data page after a successful export; [now]
  /// is only ever passed by tests.
  Future<void> markExported({DateTime? now}) async {
    final db = await AppDatabase.instance.database;
    await db.insert(AppDatabase.metaTable, {
      'key': lastExportKey,
      'value': (now ?? DateTime.now()).toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// When this device last saved a backup, or null when it never has.
  Future<DateTime?> lastExportAt() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      AppDatabase.metaTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [lastExportKey],
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['value'] as String? ?? '');
  }

  /// Whether the owner should be reminded to export: there is something worth
  /// backing up and either nothing has ever been exported or the last one is
  /// older than [reminderAfter].
  ///
  /// An empty registry never reminds, so a brand-new device is not nagged
  /// before there is anything to keep.
  Future<bool> reminderDue({DateTime? now}) async {
    final students = (await counts()).students;
    if (students == 0) return false;
    final last = await lastExportAt();
    if (last == null) return true;
    final moment = now ?? DateTime.now();
    return moment.toUtc().difference(last.toUtc()) > reminderAfter;
  }

  /// The backup file, ready to be saved.
  Future<Uint8List> exportBytes() async {
    final db = await AppDatabase.instance.database;
    Set<int>? classDays;
    final tables = await db.transaction((txn) async {
      classDays = await ClassSchedule.readFrom(txn);
      return <String, Object?>{
        'students': await txn.query('students', orderBy: 'id'),
        'promotions': await txn.query('promotions', orderBy: 'id'),
        'achievements': await txn.query('achievements', orderBy: 'id'),
        'attendance': await txn.query('attendance', orderBy: 'id'),
      };
    });
    final document = <String, Object?>{
      'format': formatName,
      'version': formatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      ...tables,
      if (classDays != null) 'classDays': [...classDays!]..sort(),
    };
    var size = 0;
    for (final table in tables.values) {
      for (final row in table! as List) {
        for (final value in (row as Map).values) {
          if (value is String) size += value.length;
        }
      }
    }
    if (size > _backgroundThreshold) {
      return compute(_encodeBackup, document);
    }
    return _encodeBackup(document);
  }

  /// Adds the records of a backup file to this device.
  ///
  /// Everything happens in one transaction: if anything goes wrong, nothing of
  /// the file is kept. Throws [BackupFormatException] for a file that is not a
  /// backup of this app.
  Future<ImportResult> importBytes(Uint8List bytes) async {
    final Object? decoded = bytes.length > _backgroundThreshold
        ? await compute(_decodeBackup, bytes)
        : _decodeBackup(bytes);
    if (decoded is! Map || decoded['format'] != formatName) {
      throw const BackupFormatException(
        'This file is not a backup made by this app.',
      );
    }
    final version = decoded['version'];
    if (version is! int || version < 1) {
      throw const BackupFormatException(
        'This file is not a backup made by this app.',
      );
    }
    if (version > formatVersion) {
      throw const BackupFormatException(
        'This backup was made by a newer version of the app. '
        'Update the app and try again.',
      );
    }
    final students = _rows(decoded['students'], required: true);
    final promotions = _rows(decoded['promotions']);
    final achievements = _rows(decoded['achievements']);
    // A backup made before attendance existed has no such table: it is simply
    // empty, and the rest of the file imports exactly as it always did.
    final attendance = _rows(decoded['attendance']);

    final db = await AppDatabase.instance.database;
    return db.transaction((txn) async {
      final studentColumns = await _columns(txn, 'students', {'id'});
      final promotionColumns = await _columns(txn, 'promotions', {
        'id',
        'student_id',
      });
      final achievementColumns = await _columns(txn, 'achievements', {
        'id',
        'student_id',
      });
      final attendanceColumns = await _columns(txn, 'attendance', {
        'id',
        'student_id',
      });

      // The students already here, so a student the backup shares with this
      // device is recognised instead of being added a second time. The stable
      // uid is the identity when both sides carry one — it survives a rename
      // and a renumbering — and the (number + name) pair is the fallback so a
      // backup written before uids existed still matches.
      final byKey = <String, int>{};
      final byUid = <String, int>{};
      final usedNumbers = <String>{};
      final usedUids = <String>{};
      final existing = await txn.query(
        'students',
        columns: ['id', 'student_no', 'name', 'uid'],
      );
      for (final row in existing) {
        final id = row['id'] as int;
        final no = row['student_no'] as String? ?? '';
        byKey[_key(no, row['name'] as String? ?? '')] = id;
        usedNumbers.add(no);
        final uid = (row['uid'] as String? ?? '').trim();
        if (isStudentUid(uid)) {
          byUid[uid] = id;
          usedUids.add(uid);
        }
      }

      var addedStudents = 0;
      var matchedStudents = 0;
      var skipped = 0;
      final idMap = <int, int>{}; // student id in the file -> id on this device

      for (final row in students) {
        final oldId = _asInt(row['id']);
        final clean = _clean(row, studentColumns);
        final name = (clean['name'] as String? ?? '').trim();
        if (oldId == null || name.isEmpty) {
          skipped++;
          continue;
        }
        clean['name'] = name;
        if (!_sexes.contains(clean['sex'])) clean['sex'] = '';

        var uid = (clean['uid'] as String? ?? '').trim();
        // Anything that is not a real uid (an empty value from an older file,
        // or a hand-edited one) is treated as "no identity" rather than trusted.
        if (!isStudentUid(uid)) uid = '';
        var no = (clean['student_no'] as String? ?? '').trim();

        final already =
            (uid.isEmpty ? null : byUid[uid]) ?? byKey[_key(no, name)];
        if (already != null) {
          idMap[oldId] = already;
          matchedStudents++;
          continue;
        }

        // A brand-new student here: they get an identity of their own if the
        // file did not already carry a usable one...
        if (uid.isEmpty || usedUids.contains(uid)) uid = StudentUid.generate();
        usedUids.add(uid);
        clean['uid'] = uid;

        // ...and a number this device already gave to somebody else (or none
        // at all) is replaced by the next free one. The student keeps
        // everything else.
        if (no.isEmpty || usedNumbers.contains(no)) {
          do {
            no = await _students.mintStudentNo(txn);
          } while (usedNumbers.contains(no));
        }
        clean['student_no'] = no;
        usedNumbers.add(no);
        final newId = await txn.insert('students', clean);
        byKey[_key(no, name)] = newId;
        byUid[uid] = newId;
        idMap[oldId] = newId;
        addedStudents++;
      }

      // One promotion per student: a student who already has one here keeps it.
      final withPromotion = <int>{
        for (final row in await txn.query(
          'promotions',
          columns: ['student_id'],
        ))
          row['student_id'] as int,
      };
      var addedPromotions = 0;
      for (final row in promotions) {
        final oldStudent = _asInt(row['student_id']);
        final target = oldStudent == null ? null : idMap[oldStudent];
        if (target == null) {
          skipped++;
          continue;
        }
        if (withPromotion.contains(target)) continue;
        await txn.insert('promotions', {
          ..._clean(row, promotionColumns),
          'student_id': target,
        });
        withPromotion.add(target);
        addedPromotions++;
      }

      // An award already on file for the same student, date, event and medal is
      // not added again, which is what makes importing the same backup twice a
      // no-op.
      String awardKey(Object target, Map<String, Object?> award) =>
          '$target\u0000${award['achievement_date']}\u0000${award['event']}'
          '\u0000${award['award']}';
      final seenAwards = <String>{
        for (final row in await txn.query(
          'achievements',
          columns: ['student_id', 'achievement_date', 'event', 'award'],
        ))
          awardKey(row['student_id'] as int, row),
      };
      var addedAchievements = 0;
      for (final row in achievements) {
        final oldStudent = _asInt(row['student_id']);
        final target = oldStudent == null ? null : idMap[oldStudent];
        final clean = _clean(row, achievementColumns);
        if (target == null || !_awards.contains(clean['award'])) {
          skipped++;
          continue;
        }
        if (!seenAwards.add(awardKey(target, clean))) continue;
        await txn.insert('achievements', {...clean, 'student_id': target});
        addedAchievements++;
      }

      // One check-in per student per day, the same rule the table enforces: a
      // day the student already has here keeps the time it was recorded with,
      // so importing the same file twice, or a backup that shares some scans
      // with this device, never counts a day twice.
      final seenDays = <String>{
        for (final row in await txn.query(
          'attendance',
          columns: ['student_id', 'attended_on'],
        ))
          '${row['student_id']}\u0000${row['attended_on']}',
      };
      var addedAttendance = 0;
      for (final row in attendance) {
        final oldStudent = _asInt(row['student_id']);
        final target = oldStudent == null ? null : idMap[oldStudent];
        final clean = _clean(row, attendanceColumns);
        final day = (clean['attended_on'] as String? ?? '').trim();
        if (target == null || !_dayPattern.hasMatch(day)) {
          skipped++;
          continue;
        }
        if (!seenDays.add('$target\u0000$day')) continue;
        final at = (clean['checked_in_at'] as String? ?? '').trim();
        await txn.insert('attendance', {
          ...clean,
          'student_id': target,
          'attended_on': day,
          'checked_in_at': at.isEmpty ? '${day}T00:00:00.000' : at,
        });
        addedAttendance++;
      }

      // A student who came from a backup made before enrolment dates existed
      // has none yet. Give each the best date the data holds (the day of their
      // first check-in, the one just imported included, otherwise today); a
      // student the file did carry a date for, or one already here, is left
      // alone.
      await AppDatabase.backfillCreatedAt(txn);

      // A backup that carries class days fills them in only when this device
      // has never set them: an import never overwrites the owner's schedule.
      final importedDays = ClassSchedule.fromList(decoded['classDays']);
      if (importedDays != null && await ClassSchedule.readFrom(txn) == null) {
        await ClassSchedule.writeTo(txn, importedDays);
      }

      return ImportResult(
        addedStudents: addedStudents,
        matchedStudents: matchedStudents,
        addedPromotions: addedPromotions,
        addedAchievements: addedAchievements,
        addedAttendance: addedAttendance,
        skipped: skipped,
      );
    }).then((result) {
      // An import writes straight to the tables, bypassing the storage
      // classes' own insert methods, so their revision counters have to be
      // bumped here — otherwise the Promotion and Achievement pages would
      // not notice the rows this just added.
      StudentStorage.revision++;
      PromotionStorage.revision++;
      AchievementStorage.revision++;
      AttendanceStorage.revision++;
      return result;
    });
  }

  static String _key(String studentNo, String name) =>
      '${studentNo.trim()}\u0000${name.trim().toLowerCase()}';

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// The rows of one table in the file, as plain maps. A table the file does not
  /// hold is treated as empty, except where [required] says the file is not a
  /// usable backup without it.
  static List<Map<String, Object?>> _rows(
    Object? value, {
    bool required = false,
  }) {
    if (value == null && !required) return const [];
    if (value is! List) {
      throw const BackupFormatException(
        'This backup file is damaged and cannot be imported.',
      );
    }
    return [
      for (final item in value)
        if (item is Map) {for (final key in item.keys) '$key': item[key]},
    ];
  }

  /// The columns this device's table has, minus [skip]. Reading them from the
  /// database means a backup from an older or newer version still imports: the
  /// columns both sides know are carried over, the rest is ignored or defaults.
  static Future<Set<String>> _columns(
    DatabaseExecutor db,
    String table,
    Set<String> skip,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return {
      for (final column in info)
        if (!skip.contains(column['name'])) column['name'] as String,
    };
  }

  /// The values of [row] for [columns], as text (every column besides the ids
  /// is text).
  static Map<String, Object?> _clean(
    Map<String, Object?> row,
    Set<String> columns,
  ) => {
    for (final column in columns)
      if (row.containsKey(column)) column: row[column]?.toString() ?? '',
  };
}
