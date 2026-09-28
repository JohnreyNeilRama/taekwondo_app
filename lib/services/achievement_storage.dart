import 'dart:convert';
import 'dart:io';

import '../models/achievement_record.dart';

/// Loads and saves achievement records on the device, using the same plain
/// file I/O approach as [StudentStorage] and [PromotionStorage] so the awards
/// live in their own file beside the registry and survive restarts.
class AchievementStorage {
  static const String _fileName = 'achievements_v1.json';
  static const String _dirName = 'tkd_app';

  /// Tests point this at a throwaway file so they never touch real data.
  static File? debugOverrideFile;

  static File? _resolvedFile;

  static File get _file {
    final override = debugOverrideFile;
    if (override != null) return override;
    return _resolvedFile ??= _resolveFile();
  }

  static File _resolveFile() {
    final env = Platform.environment;
    final base =
        env['APPDATA'] ??
        _roamingFromUserProfile(env) ??
        env['HOME'] ??
        _stableTempBase();
    return File(
      '$base${Platform.pathSeparator}$_dirName'
      '${Platform.pathSeparator}$_fileName',
    );
  }

  /// `%USERPROFILE%\AppData\Roaming`, or null when USERPROFILE is absent.
  static String? _roamingFromUserProfile(Map<String, String> env) {
    final profile = env['USERPROFILE'];
    if (profile == null || profile.isEmpty) return null;
    return '$profile${Platform.pathSeparator}AppData'
        '${Platform.pathSeparator}Roaming';
  }

  /// Fixed-name fallback directory inside the system temp folder, so data
  /// written here still survives restarts.
  static String _stableTempBase() =>
      '${Directory.systemTemp.path}${Platform.pathSeparator}$_dirName-data';

  /// Reads every saved achievement. Returns an empty list on first launch and
  /// never throws: unreadable data is ignored so the app can still start.
  Future<List<AchievementRecord>> loadRecords() async {
    try {
      final file = _file;
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return [
        for (final item in decoded)
          AchievementRecord.fromJson(item as Map<String, dynamic>),
      ];
    } catch (_) {
      return [];
    }
  }

  /// Overwrites the stored achievements with [records].
  Future<void> saveRecords(List<AchievementRecord> records) async {
    final file = _file;
    await file.parent.create(recursive: true);
    final raw = jsonEncode([for (final r in records) r.toJson()]);
    await file.writeAsString(raw, flush: true);
  }
}
