import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// The app's SQLite database: one file holding the registry, the promotion
/// records and the achievements.
///
/// Everything the app saves goes through [database], so the screens and the
/// storage classes never open a file themselves.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const String _dbName = 'tkd_app.db';
  static const int _dbVersion = 4;

  /// A small key/value table for bookkeeping. Registry numbers no longer use
  /// it — `StudentStorage` keeps them sequential itself — but the table stays,
  /// so a database created by an earlier version keeps exactly the same shape.
  static const String metaTable = 'app_meta';

  /// Database to open instead of the real file. Tests set this to
  /// [inMemoryDatabasePath] so they never touch the registry on the device;
  /// production code leaves it null.
  @visibleForTesting
  static String? debugOverridePath;

  Future<Database>? _opening;

  /// The open database, opened once and shared by every storage class.
  ///
  /// A failed open is deliberately not remembered: the caller gets the error
  /// (so the app can say what went wrong) and the next call tries again, which
  /// is what lets the "Try again" button on the startup screen work.
  Future<Database> get database {
    final opening = _opening;
    if (opening != null) return opening;
    final fresh = _open();
    _opening = fresh;
    // Keeps the failed future handled, so a database that cannot be opened
    // reports its error where it is awaited instead of crashing the zone.
    fresh.then((_) {}, onError: (Object _) {
      if (identical(_opening, fresh)) _opening = null;
    });
    return fresh;
  }

  /// Closes the open database and forgets it, so the next call to [database]
  /// starts from a brand new (empty) one. Visible for testing only.
  @visibleForTesting
  static Future<void> debugReset() async {
    final opening = instance._opening;
    instance._opening = null;
    debugOverridePath = null;
    if (opening == null) return;
    // A widget test can end while a screen is still in the middle of a query.
    // That query can never finish once the test's clock is gone, and closing
    // the connection waits for it, so neither step is allowed to wait forever:
    // a connection that will not close is abandoned instead of hanging the run.
    try {
      final open = await opening.timeout(const Duration(seconds: 3));
      await open.close().timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Abandoned; the next test opens its own database.
    } catch (_) {
      // A database that never opened has nothing to close.
    }
  }

  Future<String> _resolvePath() async {
    final override = debugOverridePath;
    if (override != null) return override;
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData == null) {
        throw StateError('APPDATA is not set');
      }
      return p.join(appData, 'tkd_app', _dbName);
    }
    return p.join(await getDatabasesPath(), _dbName);
  }

  Future<Database> _open() async {
    final path = await _resolvePath();
    // A real file needs its folder; an in-memory path has none.
    if (path != inMemoryDatabasePath) {
      await Directory(p.dirname(path)).create(recursive: true);
    }

    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE students (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  student_no            TEXT    NOT NULL UNIQUE,
  name                  TEXT    NOT NULL,
  nickname              TEXT    NOT NULL DEFAULT '',
  home_address          TEXT    NOT NULL DEFAULT '',
  telephone_nos         TEXT    NOT NULL DEFAULT '',
  cellphone_no          TEXT    NOT NULL DEFAULT '',
  email                 TEXT    NOT NULL DEFAULT '',
  birth_date            TEXT    NOT NULL DEFAULT '',
  religion              TEXT    NOT NULL DEFAULT '',
  sex                   TEXT    NOT NULL DEFAULT ''
                                CHECK (sex IN ('', 'Male', 'Female')),
  status                TEXT    NOT NULL DEFAULT '',
  school_name           TEXT    NOT NULL DEFAULT '',
  grade_year_course     TEXT    NOT NULL DEFAULT '',
  company_name_address  TEXT    NOT NULL DEFAULT '',
  father_name           TEXT    NOT NULL DEFAULT '',
  father_occupation     TEXT    NOT NULL DEFAULT '',
  father_office_address TEXT    NOT NULL DEFAULT '',
  father_contact_nos    TEXT    NOT NULL DEFAULT '',
  mother_name           TEXT    NOT NULL DEFAULT '',
  mother_occupation     TEXT    NOT NULL DEFAULT '',
  mother_office_address TEXT    NOT NULL DEFAULT '',
  mother_contact_nos    TEXT    NOT NULL DEFAULT '',
  guardian_name         TEXT    NOT NULL DEFAULT '',
  guardian_contact_nos  TEXT    NOT NULL DEFAULT '',
  previous_martial_arts TEXT    NOT NULL DEFAULT '',
  other_hobbies_sports  TEXT    NOT NULL DEFAULT '',
  health_conditions     TEXT    NOT NULL DEFAULT '',
  photo_base64          TEXT    NOT NULL DEFAULT '',
  photo_full_base64     TEXT    NOT NULL DEFAULT '',
  deleted_at            TEXT    NOT NULL DEFAULT '',
  uid                   TEXT    NOT NULL DEFAULT ''
)
''');

        await db.execute('''
CREATE TABLE promotions (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id          INTEGER NOT NULL UNIQUE,
  belt                TEXT    NOT NULL DEFAULT '',
  last_promotion_date TEXT    NOT NULL DEFAULT '',
  FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
)
''');

        await db.execute('''
CREATE TABLE achievements (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id       INTEGER NOT NULL,
  achievement_date TEXT    NOT NULL DEFAULT '',
  event            TEXT    NOT NULL,
  award            TEXT    NOT NULL
                           CHECK (award IN ('Gold', 'Silver', 'Bronze')),
  FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
)
''');

        await db.execute(
          'CREATE INDEX idx_achievements_student_id '
          'ON achievements (student_id)',
        );

        await db.execute(_createMetaTable);
      },
      // A phone that already holds the v1 registry is brought up to date here
      // instead of being refused, so an update never costs the owner their
      // records. The upgrade is additive only: the original picture a v1 row
      // keeps in `photo_base64` is left exactly where it is, so nothing that
      // was saved can be lost by opening the app on a newer version.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE students ADD COLUMN photo_full_base64 "
            "TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(_createMetaTable);
        }
        // Version 3 adds the Trash: a student who is deleted keeps their row
        // and gets the moment of the deletion here, an empty value meaning
        // "not deleted". Additive only, so every existing record is untouched
        // and simply reads as not deleted.
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE students ADD COLUMN deleted_at "
            "TEXT NOT NULL DEFAULT ''",
          );
        }
        // Version 4 adds the stable identity of a student: a random value
        // minted once and never changed, used by the backup import to
        // recognise the same person after a rename or a renumbering. Additive
        // only, so every existing record is untouched and reads as "not
        // stamped yet"; `StudentStorage.ensureStudentUids` fills the value in
        // on the first launch after the update.
        if (oldVersion < 4) {
          await db.execute(
            "ALTER TABLE students ADD COLUMN uid TEXT NOT NULL DEFAULT ''",
          );
        }
      },
    );
  }

  /// The bookkeeping table, kept in one place so `onCreate` and `onUpgrade`
  /// can never disagree about its shape.
  static const String _createMetaTable =
      'CREATE TABLE IF NOT EXISTS $metaTable ('
      'key TEXT PRIMARY KEY, '
      'value TEXT NOT NULL'
      ')';

  /// Whether the saved file is still internally consistent, so the owner can
  /// check the database instead of finding out the hard way.
  ///
  /// Returns true for "ok" (the only answer a healthy file gives).
  Future<bool> isHealthy() async {
    final db = await database;
    final rows = await db.rawQuery('PRAGMA integrity_check');
    if (rows.isEmpty) return false;
    return rows.first.values.first?.toString().toLowerCase() == 'ok';
  }

  /// Moves a database file the app cannot open out of the way and starts a new
  /// empty one, so a corrupt file (or a phone that ran out of space) does not
  /// leave the app unusable.
  ///
  /// Returns the path the damaged file was kept under, or null when there was
  /// no file to move. The moved file is never deleted: it is the only way the
  /// records it still holds can be recovered by hand.
  Future<String?> recoverFromUnopenableFile() async {
    final path = await _resolvePath();
    await _forgetOpen();
    if (path == inMemoryDatabasePath) return null;

    final file = File(path);
    if (!file.existsSync()) return null;

    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp('[:.]'), '-');
    final damaged = '$path.damaged-$stamp';
    var moved = false;
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      final source = File('$path$suffix');
      if (!source.existsSync()) continue;
      try {
        await source.rename('$damaged$suffix');
        moved = true;
      } catch (_) {
        // A file that cannot be moved is better left where it is than deleted.
      }
    }
    return moved ? damaged : null;
  }

  /// Closes and forgets the open database without touching its file.
  Future<void> _forgetOpen() async {
    final opening = _opening;
    _opening = null;
    if (opening == null) return;
    try {
      final open = await opening;
      await open.close();
    } catch (_) {
      // Nothing to close when the open itself failed.
    }
  }
}
