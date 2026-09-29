import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/achievement_record.dart';
import '../models/belt.dart';
import '../models/student.dart';
import 'app_database.dart';

/// One-time import of the JSON files the app used before it had a database.
///
/// The files are only ever read: nothing here writes to, renames or deletes
/// `students_v1.json`, `promotions_v1.json` or `achievements_v1.json`, so a
/// failed or repeated import can never lose what the owner already had. The
/// import runs while the `students` table is still empty and does all its work
/// in one transaction, which makes it idempotent and safe to run on every
/// launch.
class LegacyJsonImporter {
  /// The folder holding the legacy JSON files. Tests point this at a throwaway
  /// folder; production code leaves it null.
  @visibleForTesting
  static Directory? debugOverrideDirectory;

  static const String _dirName = 'tkd_app';
  static const String _studentsFile = 'students_v1.json';
  static const String _promotionsFile = 'promotions_v1.json';
  static const String _achievementsFile = 'achievements_v1.json';

  /// Imports the legacy files when they exist and the registry is still empty.
  /// Returns how many students were imported (0 when there was nothing to do).
  ///
  /// Never throws: a missing, empty or unreadable file simply leaves the
  /// database as it is, which is also what happens on a phone, where the JSON
  /// files were never written.
  Future<int> importIfNeeded() async {
    try {
      final db = await AppDatabase.instance.database;
      if (await _hasSavedStudents(db)) return 0;

      final students = await _readStudents();
      if (students.isEmpty) return 0;
      final promotions = await _readRecords(_promotionsFile);
      final achievements = await _readRecords(_achievementsFile);

      await db.transaction((txn) async {
        // The registry number is the link the old files used, so every import
        // records which id that number became.
        final idsByStudentNo = <String, int>{};
        for (final student in students) {
          final number = student.studentNo;
          if (number.isNotEmpty && idsByStudentNo.containsKey(number)) {
            // Two records claiming one registry number: the number is unique in
            // the database, so the later duplicate is left out instead of
            // failing the import of everything else.
            continue;
          }
          final id = await txn.insert('students', student.toMap());
          if (number.isNotEmpty) idsByStudentNo[number] = id;
        }
        await _importPromotions(txn, promotions, idsByStudentNo);
        await _importAchievements(txn, achievements, idsByStudentNo);
      });
      return students.length;
    } catch (_) {
      return 0;
    }
  }

  /// Whether the registry already holds records, in which case there is
  /// nothing to bring across.
  Future<bool> _hasSavedStudents(Database db) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM students');
    return (rows.first['total'] as int? ?? 0) > 0;
  }

  /// The belt of every imported record, at most one record per student.
  Future<void> _importPromotions(
    DatabaseExecutor txn,
    List<Map<String, dynamic>> records,
    Map<String, int> idsByStudentNo,
  ) async {
    final saved = <int>{};
    for (final record in records) {
      final studentId = idsByStudentNo[_text(record['studentNo'])];
      // A record whose student is gone is skipped rather than failing the
      // whole import, and the second record of one student is ignored: the
      // database allows one promotion per student.
      if (studentId == null || !saved.add(studentId)) continue;
      await txn.insert('promotions', {
        'student_id': studentId,
        // Belts written before the grade-based curriculum are mapped onto the
        // grade that replaced them, exactly as the Promotion page did.
        'belt': BeltCatalog.normalize(_text(record['belt'])),
        'last_promotion_date': _text(record['lastPromotionDate']),
      });
    }
  }

  /// Every imported achievement, linked to the id of its student.
  Future<void> _importAchievements(
    DatabaseExecutor txn,
    List<Map<String, dynamic>> records,
    Map<String, int> idsByStudentNo,
  ) async {
    for (final record in records) {
      final studentId = idsByStudentNo[_text(record['studentNo'])];
      if (studentId == null) continue;
      final award = _text(record['award']);
      // The award column only accepts the three real medals, so an award the
      // old file could not describe is left out instead of aborting the
      // import and with it every other record.
      if (Award.fromLabel(award) == null) continue;
      await txn.insert('achievements', {
        'student_id': studentId,
        'achievement_date': _text(record['date']),
        'event': _text(record['event']),
        'award': award,
      });
    }
  }

  /// The students in `students_v1.json`, or an empty list when the file is
  /// absent or unreadable.
  Future<List<Student>> _readStudents() async {
    final items = await _readRecords(_studentsFile);
    return [for (final item in items) Student.fromJson(item)];
  }

  /// One legacy JSON file as a list of objects.
  Future<List<Map<String, dynamic>>> _readRecords(String fileName) async {
    try {
      final file = await _legacyFile(fileName);
      if (file == null || !await file.exists()) return const [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    } catch (_) {
      // A corrupt file is treated as "nothing to import": the app must start.
      return const [];
    }
  }

  /// The legacy file, or null when none of the known folders is available.
  Future<File?> _legacyFile(String fileName) async {
    final directory = _legacyDirectory();
    if (directory == null) return null;
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  /// Where the JSON files live: `%APPDATA%\tkd_app` on Windows, which is
  /// exactly where the file-based storage kept them. Falls back the same way
  /// it used to and returns null when nothing is set — on a phone there is no
  /// such folder and no data to bring across.
  static Directory? _legacyDirectory() {
    final override = debugOverrideDirectory;
    if (override != null) return override;
    final env = Platform.environment;
    final base =
        env['APPDATA'] ?? _roamingFromUserProfile(env) ?? env['HOME'] ?? '';
    if (base.isEmpty) return null;
    return Directory('$base${Platform.pathSeparator}$_dirName');
  }

  /// `%USERPROFILE%\AppData\Roaming`, or null when USERPROFILE is absent.
  static String? _roamingFromUserProfile(Map<String, String> env) {
    final profile = env['USERPROFILE'];
    if (profile == null || profile.isEmpty) return null;
    return '$profile${Platform.pathSeparator}AppData'
        '${Platform.pathSeparator}Roaming';
  }

  /// Reads one legacy value, tolerating a missing or non-text entry.
  static String _text(Object? value) => value is String ? value : '';
}
