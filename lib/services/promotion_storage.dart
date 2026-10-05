import '../models/promotion_record.dart';
import 'app_database.dart';

/// Reads and writes belt / promotion records in the `promotions` table.
///
/// A record belongs to a student through `student_id`, and the student's
/// registry number and name are read back from the `students` table with a
/// JOIN — so the list always shows the current name and no copy of it can go
/// stale. One student holds one record: saving again replaces it.
class PromotionStorage {
  static const String _table = 'promotions';

  /// Bumped by every [saveForStudent] so the Promotion page can tell whether
  /// its records actually changed since it last read them, instead of
  /// re-reading the whole table on every tab visit whether or not anything is
  /// different.
  static int revision = 0;

  /// The JOIN that adds the registry number and the current name of the
  /// student to every promotion row.
  static const String _selectWithStudent = '''
SELECT p.id, p.student_id, p.belt, p.last_promotion_date,
       s.student_no, s.name AS student_name
FROM promotions p
JOIN students s ON s.id = p.student_id AND s.deleted_at = ''
''';

  /// Every saved promotion, oldest first.
  Future<List<PromotionRecord>> loadRecords() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('$_selectWithStudent ORDER BY p.id');
    return [for (final row in rows) PromotionRecord.fromMap(row)];
  }

  /// Saves the promotion of one student, replacing the record that student
  /// already has, and returns it with the id it was stored under.
  ///
  /// The row is looked up first and then inserted or updated: `ON CONFLICT DO
  /// UPDATE` needs a newer SQLite than the older Android phones ship with.
  Future<PromotionRecord> saveForStudent(PromotionRecord record) async {
    final db = await AppDatabase.instance.database;
    final id = await db.transaction((txn) async {
      final existing = await txn.query(
        _table,
        columns: ['id'],
        where: 'student_id = ?',
        whereArgs: [record.studentId],
        limit: 1,
      );
      if (existing.isEmpty) {
        return txn.insert(_table, record.toMap());
      }
      final existingId = existing.first['id'] as int;
      await txn.update(
        _table,
        record.toMap(),
        where: 'id = ?',
        whereArgs: [existingId],
      );
      return existingId;
    });
    revision++;
    return record.withId(id);
  }
}
