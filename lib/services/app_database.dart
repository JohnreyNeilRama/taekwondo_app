import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const String _dbName = 'tkd_app.db';
  static const int _dbVersion = 1;

  Future<Database>? _opening;

  Future<Database> get database => _opening ??= _open();

  Future<String> _resolvePath() async {
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
    await Directory(p.dirname(path)).create(recursive: true);

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
  photo_base64          TEXT    NOT NULL DEFAULT ''
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
      },
    );
  }
}
