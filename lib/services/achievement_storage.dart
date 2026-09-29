import '../models/achievement_record.dart';
import 'app_database.dart';

/// Reads and writes achievement records in the `achievements` table.
///
/// Every record belongs to a student through `student_id`, and the student's
/// registry number and name are read back from the `students` table with a
/// JOIN — so the list always shows the current name and no copy of it can go
/// stale. One student can hold any number of records, and each of them is
/// added, changed or removed on its own.
class AchievementStorage {
  static const String _table = 'achievements';

  /// The JOIN that adds the registry number and the current name of the
  /// student to every achievement row.
  static const String _selectWithStudent = '''
SELECT a.id, a.student_id, a.achievement_date, a.event, a.award,
       s.student_no, s.name AS student_name
FROM achievements a
JOIN students s ON s.id = a.student_id
''';

  /// Every saved achievement, oldest first.
  Future<List<AchievementRecord>> loadRecords() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('$_selectWithStudent ORDER BY a.id');
    return [for (final row in rows) AchievementRecord.fromMap(row)];
  }

  /// The records of one student, used by the student detail screen.
  Future<List<AchievementRecord>> loadForStudent(int studentId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '$_selectWithStudent WHERE a.student_id = ? ORDER BY a.id',
      [studentId],
    );
    return [for (final row in rows) AchievementRecord.fromMap(row)];
  }

  /// Saves [record] as a new achievement and returns it with the id the
  /// database assigned.
  Future<AchievementRecord> insert(AchievementRecord record) async {
    final db = await AppDatabase.instance.database;
    final id = await db.insert(_table, record.toMap());
    return record.withId(id);
  }

  /// Writes [record] back onto its own row; the student it belongs to never
  /// changes.
  Future<void> update(AchievementRecord record) async {
    final id = record.id;
    if (id == null) {
      throw ArgumentError('An achievement without an id cannot be updated.');
    }
    final db = await AppDatabase.instance.database;
    await db.update(_table, record.toMap(), where: 'id = ?', whereArgs: [id]);
  }

  /// Removes one achievement, leaving the other awards of that student alone.
  Future<void> delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
