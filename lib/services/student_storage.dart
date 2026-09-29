import 'package:sqflite/sqflite.dart';

import '../models/student.dart';
import 'app_database.dart';

/// Everything one deleted student owned, captured before the database removed
/// it, so an Undo can put the student, their promotion record and their
/// achievements back exactly as they were: same ids, same registry number.
///
/// The rows are kept as raw table maps on purpose — re-inserting them
/// unchanged is what makes the restored records identical to the deleted ones,
/// including the ids the achievements are keyed by.
class DeletedStudent {
  const DeletedStudent({
    required this.student,
    this.promotion,
    this.achievements = const [],
  });

  /// The `students` row as it was before the delete.
  final Map<String, Object?> student;

  /// The single `promotions` row of that student, or null when they had none.
  final Map<String, Object?>? promotion;

  /// Every `achievements` row of that student.
  final List<Map<String, Object?>> achievements;

  /// The name of the deleted student, used by the Undo message.
  String get name => student['name'] as String? ?? '';
}

/// Reads and writes the student registry in the `students` table.
///
/// A student is identified by [Student.id] — the database primary key — from
/// here on: promotion and achievement records point at that id, which is what
/// keeps one person to exactly one registry row.
class StudentStorage {
  static const String _table = 'students';

  /// Every saved student, in registry order.
  Future<List<Student>> loadStudents() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(_table, orderBy: 'id');
    return [for (final row in rows) Student.fromMap(row)];
  }

  /// Saves [student] and returns it with the id and registry number the
  /// database assigned.
  ///
  /// A record without a registry number is given the next `TKD-####` inside
  /// the transaction, so two quick taps can never mint the same number. If the
  /// UNIQUE index rejects the number anyway (a record created in the meantime
  /// took it), the number is minted once more before the error is passed on.
  Future<Student> insert(Student student) async {
    final db = await AppDatabase.instance.database;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await db.transaction((txn) => _insert(txn, student));
      } on DatabaseException catch (error) {
        if (attempt == 0 && error.isUniqueConstraintError()) continue;
        rethrow;
      }
    }
    // Only reachable if the retry above also failed, which rethrows instead.
    throw StateError('The student could not be saved.');
  }

  Future<Student> _insert(DatabaseExecutor db, Student student) async {
    final studentNo = student.studentNo.isNotEmpty
        ? student.studentNo
        : _formatStudentNo(await _nextStudentNumber(db));
    final saved = student.withStudentNo(studentNo);
    final id = await db.insert(_table, saved.toMap());
    return saved.withId(id);
  }

  /// The registry number the next saved student should get: one past the
  /// highest `TKD-####` already in the table.
  Future<int> _nextStudentNumber(DatabaseExecutor db) async {
    final rows = await db.query(_table, columns: ['student_no']);
    var highest = 0;
    for (final row in rows) {
      final match = RegExp(
        r'^TKD-(\d+)$',
      ).firstMatch(row['student_no'] as String? ?? '');
      if (match == null) continue;
      final number = int.tryParse(match.group(1)!);
      if (number != null && number > highest) highest = number;
    }
    return highest + 1;
  }

  static String _formatStudentNo(int number) =>
      'TKD-${number.toString().padLeft(4, '0')}';

  /// Writes every column of [student] back onto its row. The registry number
  /// is written too, but it is the same one the record already had, so editing
  /// a student never renumbers them.
  Future<void> update(Student student) async {
    final id = student.id;
    if (id == null) {
      throw ArgumentError('A student without an id cannot be updated.');
    }
    final db = await AppDatabase.instance.database;
    await db.update(_table, student.toMap(), where: 'id = ?', whereArgs: [id]);
  }

  /// Removes the student saved as [id] and hands back everything they owned.
  ///
  /// The foreign keys cascade, so the promotion record and the achievements go
  /// with the student; the returned snapshot is the only copy left, which is
  /// what the Undo action restores.
  Future<DeletedStudent> delete(int id) async {
    final db = await AppDatabase.instance.database;
    return db.transaction((txn) async {
      final students = await txn.query(
        _table,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (students.isEmpty) {
        throw StateError('The student is no longer saved.');
      }
      final promotions = await txn.query(
        'promotions',
        where: 'student_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final achievements = await txn.query(
        'achievements',
        where: 'student_id = ?',
        whereArgs: [id],
      );
      await txn.delete(_table, where: 'id = ?', whereArgs: [id]);
      return DeletedStudent(
        student: students.first,
        promotion: promotions.isEmpty ? null : promotions.first,
        achievements: achievements,
      );
    });
  }

  /// Puts a deleted student back exactly as they were.
  ///
  /// The original id is written again, so the restored promotion record and
  /// achievements still belong to the student and the registry keeps the order
  /// the student had before.
  Future<void> restore(DeletedStudent deleted) async {
    if (deleted.student.isEmpty) return;
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      // The student first: the records below reference them.
      await txn.insert(_table, deleted.student);
      final promotion = deleted.promotion;
      if (promotion != null) await txn.insert('promotions', promotion);
      for (final achievement in deleted.achievements) {
        await txn.insert('achievements', achievement);
      }
    });
  }
}
