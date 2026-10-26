import '../models/belt.dart';
import '../models/promotion_record.dart';
import 'app_database.dart';

/// Reads and writes belt / promotion records in the `promotions` table.
///
/// A record belongs to a student through `student_id`, and the student's
/// registry number and name are read back from the `students` table with a
/// JOIN — so the list always shows the current name and no copy of it can go
/// stale. One student holds one record: saving again replaces it.
///
/// The belts a student held before their current one are kept in the
/// `promotion_history` table: [saveForStudent] archives the previous belt
/// there whenever it changes, so a promotion never erases the one before it.
class PromotionStorage {
  static const String _table = 'promotions';
  static const String _historyTable = 'promotion_history';

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

  /// The belts one student held before their current one, the most recent
  /// first.
  ///
  /// Entries are archived in the order the promotions happened, so the row id
  /// is the order — it stays right even when a date was never recorded.
  Future<List<PromotionHistoryEntry>> loadHistory(int studentId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      _historyTable,
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'id DESC',
    );
    return [for (final row in rows) PromotionHistoryEntry.fromMap(row)];
  }

  /// Saves the promotion of one student, replacing the record that student
  /// already has, and returns it with the id it was stored under.
  ///
  /// When the belt changes, the belt being replaced and its promotion date are
  /// first archived in `promotion_history`, in the same transaction, so the
  /// student's earlier belts are never lost. Saving the same belt again (for
  /// example to correct its date) is an edit, not a promotion, and archives
  /// nothing.
  ///
  /// The row is looked up first and then inserted or updated: `ON CONFLICT DO
  /// UPDATE` needs a newer SQLite than the older Android phones ship with.
  Future<PromotionRecord> saveForStudent(
    PromotionRecord record, {
    DateTime? now,
  }) async {
    final db = await AppDatabase.instance.database;
    final id = await db.transaction((txn) async {
      final existing = await txn.query(
        _table,
        columns: ['id', 'belt', 'last_promotion_date'],
        where: 'student_id = ?',
        whereArgs: [record.studentId],
        limit: 1,
      );
      if (existing.isEmpty) {
        return txn.insert(_table, record.toMap());
      }
      final row = existing.first;
      final existingId = row['id'] as int;
      // Belts saved before the grade-based curriculum are compared (and
      // archived) under the grade that replaced them, matching what the
      // Promotion page shows for them.
      final previousBelt = BeltCatalog.normalize(row['belt'] as String? ?? '');
      final previousDate = row['last_promotion_date'] as String? ?? '';
      if (previousBelt.isNotEmpty && previousBelt != record.belt) {
        // The same belt and date already archived (a save retried after a
        // failure, say) is not added a second time.
        final duplicate = await txn.query(
          _historyTable,
          columns: ['id'],
          where: 'student_id = ? AND belt = ? AND promotion_date = ?',
          whereArgs: [record.studentId, previousBelt, previousDate],
          limit: 1,
        );
        if (duplicate.isEmpty) {
          await txn.insert(_historyTable, {
            'student_id': record.studentId,
            'belt': previousBelt,
            'promotion_date': previousDate,
            'recorded_at': (now ?? DateTime.now()).toIso8601String(),
          });
        }
      }
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
