import 'dart:convert';
import 'dart:io';

import '../models/student.dart';

/// Loads and saves the student registry on the device using plain
/// file I/O — no plugins required. The whole list is stored as one
/// JSON document, which is simple and perfectly adequate for the
/// record volumes of a dojang.
class StudentStorage {
  static const String _fileName = 'students_v1.json';
  static const String _dirName = 'tkd_app';

  /// Tests point this at a throwaway file so they never touch the
  /// real registry.
  static File? debugOverrideFile;

  /// The JSON document holding every saved student. Resolved once per
  /// process and reused. Resolution order:
  ///
  /// 1. `%APPDATA%` (standard per-user roaming data on Windows)
  /// 2. `%USERPROFILE%\AppData\Roaming` (covers processes whose
  ///    environment is missing APPDATA — USERPROFILE is almost always
  ///    still set, and this is the same folder)
  /// 3. `%HOME%`
  /// 4. A *stable* fixed-name folder in the system temp directory.
  ///
  /// The last resort must never be a randomly-named temp directory:
  /// that would give every launch a fresh empty folder and make it
  /// look like all saved students vanished on restart.
  static File get _file {
    final override = debugOverrideFile;
    if (override != null) return override;
    return _resolvedFile ??= _resolveFile();
  }

  static File? _resolvedFile;

  static File _resolveFile() {
    final env = Platform.environment;
    final base = env['APPDATA'] ??
        _roamingFromUserProfile(env) ??
        env['HOME'] ??
        _stableTempBase();
    return File(
      '$base${Platform.pathSeparator}$_dirName'
      '${Platform.pathSeparator}$_fileName',
    );
  }

  /// `%USERPROFILE%\AppData\Roaming`, or null when USERPROFILE is
  /// absent.
  static String? _roamingFromUserProfile(Map<String, String> env) {
    final profile = env['USERPROFILE'];
    if (profile == null || profile.isEmpty) return null;
    return '$profile${Platform.pathSeparator}AppData'
        '${Platform.pathSeparator}Roaming';
  }

  /// Fixed-name fallback directory inside the system temp folder.
  /// Same path on every launch so data written here still survives
  /// restarts.
  static String _stableTempBase() =>
      '${Directory.systemTemp.path}${Platform.pathSeparator}$_dirName-data';

  /// Reads every saved student. Returns an empty list on first launch
  /// and never throws: if the stored data is unreadable it is ignored
  /// so the app can still start.
  Future<List<Student>> loadStudents() async {
    try {
      final file = _file;
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return [
        for (final item in decoded)
          Student.fromJson(item as Map<String, dynamic>),
      ];
    } catch (_) {
      return [];
    }
  }

  /// Overwrites the stored registry with [students].
  Future<void> saveStudents(List<Student> students) async {
    final file = _file;
    await file.parent.create(recursive: true);
    final raw = jsonEncode([for (final s in students) s.toJson()]);
    await file.writeAsString(raw, flush: true);
  }
}
