import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/student.dart';
import 'achievement_storage.dart';
import 'app_database.dart';
import 'photo_processor.dart';
import 'promotion_storage.dart';
import 'student_uid.dart';

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

/// One student in the Trash: who they are, when they were deleted and how many
/// records are waiting with them, so the Trash page can say exactly what a
/// restore brings back and what a permanent delete removes.
class TrashedStudent {
  const TrashedStudent({
    required this.student,
    required this.deletedAt,
    this.promotionCount = 0,
    this.achievementCount = 0,
  });

  /// The student, carrying the compact picture the avatars draw.
  final Student student;

  /// When the student was moved to the Trash, or null if the stored value could
  /// not be read.
  final DateTime? deletedAt;

  /// 1 when the student has a promotion (belt) record, otherwise 0.
  final int promotionCount;

  final int achievementCount;
}

/// Reads and writes the student registry in the `students` table.
///
/// A student is identified by [Student.id] — the database primary key — from
/// here on: promotion and achievement records point at that id, which is what
/// keeps one person to exactly one registry row.
///
/// Registry numbers (`TKD-####`) follow one rule. Every student who still
/// exists — active or in the Trash — holds one place in the sequence
/// `TKD-0001..M`, in the order they were added:
///
/// * moving a student to the Trash keeps their number reserved: nothing moves;
/// * restoring a student gives them back the number they never lost;
/// * deleting a student permanently removes their place, and every student
///   added after them moves up by one to close it;
/// * a new student takes the number after the last place in the sequence.
class StudentStorage {
  static const String _table = 'students';

  /// Bumped by every mutation ([insert], [update], [delete], [restore]) so a
  /// page that lists students can tell whether the registry actually changed
  /// since it last read it, instead of re-reading the whole table on every
  /// tab visit whether or not anything is different.
  static int revision = 0;

  /// Every column of a student except the original picture.
  ///
  /// The lists, the pickers and the detail screens read this set. Leaving
  /// `photo_full_base64` out is what keeps a registry of hundreds of students
  /// from pulling hundreds of full-size photos into memory every time a page is
  /// opened or a destination is selected: only the compact picture the avatars
  /// draw is carried, which is a few kilobytes per student instead of hundreds.
  static const List<String> _listColumns = [
    'id',
    'uid',
    'created_at',
    'student_no',
    'name',
    'nickname',
    'home_address',
    'telephone_nos',
    'cellphone_no',
    'email',
    'birth_date',
    'religion',
    'sex',
    'status',
    'school_name',
    'grade_year_course',
    'company_name_address',
    'father_name',
    'father_occupation',
    'father_office_address',
    'father_contact_nos',
    'mother_name',
    'mother_occupation',
    'mother_office_address',
    'mother_contact_nos',
    'guardian_name',
    'guardian_contact_nos',
    'previous_martial_arts',
    'other_hobbies_sports',
    'health_conditions',
    'photo_base64',
  ];

  /// Length of saved text above which a picture is treated as one that still
  /// has to be shrunk. A compact copy stays well under it; a full-size photo is
  /// several times over it.
  static const int _largePhotoLength = 60000;

  /// Every saved student who is not in the Trash, in registry order, carrying
  /// the compact picture only.
  Future<List<Student>> loadStudents() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      _table,
      columns: _listColumns,
      where: "deleted_at = ''",
      orderBy: 'id',
    );
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
    var studentNo = student.studentNo;
    if (studentNo.isEmpty) {
      // Packing the sequence first guarantees the numbers already saved are
      // exactly `1..count` with nothing skipped — including right after a
      // backup import left a student with a number carried over from another
      // device — so `count + 1` is always the next place and always free. A
      // student in the Trash is counted: their number is reserved, so the new
      // student goes after it instead of taking it.
      await _renumberStudents(db);
      studentNo = _formatStudentNo(await _studentCount(db) + 1);
    }
    // The stable identity is minted once here and never changed afterwards, so
    // the same person is recognised by a later backup import whatever happens
    // to their name or registry number.
    final uid = student.uid.isEmpty ? StudentUid.generate() : student.uid;
    // The enrolment time is stamped once, here, in local time (the same clock
    // the attendance days use), and never changed by an edit. A record that
    // already carries one keeps it.
    final createdAt = student.createdAt.isEmpty
        ? DateTime.now().toIso8601String()
        : student.createdAt;
    final saved = student
        .withStudentNo(studentNo)
        .withUid(uid)
        .withCreatedAt(createdAt);
    final id = await db.insert(_table, saved.toMap());
    revision++;
    return saved.withId(id);
  }

  /// How many students exist, active or in the Trash.
  Future<int> _studentCount(DatabaseExecutor db) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM $_table');
    return (rows.first['total'] as int?) ?? 0;
  }

  /// Numbers every student who is still kept — active and in the Trash — as
  /// `TKD-0001..M`, in the order they were originally added (`id` ascending,
  /// which never changes).
  ///
  /// A student in the Trash keeps a place in that sequence, which is what
  /// reserves their number: nobody else can take it while they are away. The
  /// sequence only closes up when somebody leaves it for good
  /// ([deletePermanently]), and then every student added after them, active or
  /// in the Trash, moves up by one. Moving to the Trash and restoring never
  /// change a number.
  ///
  /// Rows that already hold the right number are not touched. The others go
  /// through a temporary value first, because the column is UNIQUE and a
  /// student moving up would otherwise collide with the student whose number
  /// they are taking before that student has moved.
  ///
  /// Nothing here touches `promotions` or `achievements`: both are linked by
  /// the database id, never by this number, so no record can be pointed at the
  /// wrong student by a renumbering.
  Future<void> _renumberStudents(DatabaseExecutor db) async {
    final rows = await db.query(
      _table,
      columns: ['id', 'student_no'],
      orderBy: 'id',
    );
    final moves = <int, String>{};
    for (var i = 0; i < rows.length; i++) {
      final wanted = _formatStudentNo(i + 1);
      if (rows[i]['student_no'] != wanted) {
        moves[rows[i]['id'] as int] = wanted;
      }
    }
    if (moves.isEmpty) return;

    // First step: move every student who has to change out of the way...
    for (final id in moves.keys) {
      await db.update(
        _table,
        {'student_no': '~moving-$id'},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    // ...second step: give each one their final number. The numbers wanted are
    // exactly the ones nobody is holding any more, so nothing can collide.
    for (final entry in moves.entries) {
      await db.update(
        _table,
        {'student_no': entry.value},
        where: 'id = ?',
        whereArgs: [entry.key],
      );
    }
  }

  /// Packs the registry numbers into `TKD-0001..M` for a registry saved by an
  /// older version of the app (which could leave gaps, or carry numbers from a
  /// backup of another device). Safe to call any time: a registry that is
  /// already correct is left untouched. [StartupGate] runs this once per
  /// launch.
  /// Gives a stable identity to every student saved before uids existed.
  ///
  /// A row written by an older version has an empty `uid`; this stamps it with
  /// a fresh random one so a backup of this device and any backup imported from
  /// another can recognise the same person. Only rows with an empty uid are
  /// looked at, so after the first run this is one cheap query per launch and a
  /// student who already has an identity is never given a second one.
  ///
  /// [StartupGate] runs this once per launch, before the first screen reads the
  /// registry. Returns how many students were stamped.
  Future<int> ensureStudentUids() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(_table, columns: ['id'], where: "uid = ''");
    if (rows.isEmpty) return 0;

    await db.transaction((txn) async {
      for (final row in rows) {
        final id = row['id'] as int?;
        if (id == null) continue;
        await txn.update(
          _table,
          {'uid': StudentUid.generate()},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
    revision++;
    return rows.length;
  }

  Future<void> renumberStudents() async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) => _renumberStudents(txn));
    _touchEverything();
  }

  /// The highest `TKD-####` number in the table, trashed students included, or
  /// 0 when there is none.
  Future<int> _highestNumber(DatabaseExecutor db) async {
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
    return highest;
  }

  static String _formatStudentNo(int number) =>
      'TKD-${number.toString().padLeft(4, '0')}';

  /// Mints a number no student holds, one past the highest in the table, inside
  /// the caller's own transaction. The backup import uses it for a student
  /// whose number is already taken here; the sequence is packed again the next
  /// time a student is added and on every launch.
  Future<String> mintStudentNo(DatabaseExecutor db) async =>
      _formatStudentNo(await _highestNumber(db) + 1);

  /// Writes every column of [student] back onto its row, except the registry
  /// number: that belongs to the sequence, not to the form, so an edit can
  /// never renumber a student — and a record that was read before a permanent
  /// delete moved the numbers up can never write its old number back over the
  /// new one.
  ///
  /// The two picture columns are the other exception: an empty picture on the
  /// record means the caller is not carrying one (a list row holds the compact
  /// copy only, an untouched form holds whatever it was handed), so the stored
  /// picture is kept instead of being blanked out. An edit can therefore never
  /// wipe the photo of a student whose picture the editor never loaded.
  ///
  /// The only way to remove a picture is on purpose: [Student.clearPhoto], which
  /// the form sets when the owner presses "Remove photo", empties both copies.
  Future<void> update(Student student) async {
    final id = student.id;
    if (id == null) {
      throw ArgumentError('A student without an id cannot be updated.');
    }
    final map = student.toMap()
      ..remove('student_no')
      // The stable identity belongs to the record, not to the form: an edit can
      // never change it, and a record that was read before an update (or a form
      // that never carried the value) can never blank it.
      ..remove('uid')
      // The enrolment time is stamped when the record is created and is never
      // part of an edit, so a form can neither change nor blank it.
      ..remove('created_at');
    if (student.clearPhoto) {
      map['photo_base64'] = '';
      map['photo_full_base64'] = '';
    } else {
      if (student.photoBase64.isEmpty) map.remove('photo_base64');
      if (student.photoFullBase64.isEmpty) map.remove('photo_full_base64');
    }
    final db = await AppDatabase.instance.database;
    await db.update(_table, map, where: 'id = ?', whereArgs: [id]);
    revision++;
  }

  /// Removes the student saved as [id] and hands back everything they owned.
  ///
  /// The foreign keys cascade, so the promotion record and the achievements go
  /// with the student; the returned snapshot is the only copy left, which is
  /// what [restore] puts back. The screens no longer use this: they move a
  /// student to the Trash instead ([moveToTrash]).
  Future<DeletedStudent> delete(int id) async {
    final db = await AppDatabase.instance.database;
    final deleted = await db.transaction((txn) async {
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
    revision++;
    // The foreign keys cascade, so this may also have removed a promotion row
    // and achievement rows without ever going through PromotionStorage or
    // AchievementStorage — their own revision counters have to be bumped here
    // too, or a page caching one of those records would never notice it is
    // gone.
    PromotionStorage.revision++;
    AchievementStorage.revision++;
    return deleted;
  }

  /// Moves the student to the Trash instead of deleting them.
  ///
  /// Nothing is removed and nothing is renumbered: the row keeps its picture
  /// (both copies), its promotion record, its achievements and its registry
  /// number, and only gets the time of the deletion. The student disappears from
  /// every list, and their number stays reserved — no other student is given it
  /// — until they are restored or permanently deleted.
  Future<void> moveToTrash(int id) async {
    final db = await AppDatabase.instance.database;
    final changed = await db.update(
      _table,
      {'deleted_at': DateTime.now().toUtc().toIso8601String()},
      where: "id = ? AND deleted_at = ''",
      whereArgs: [id],
    );
    if (changed == 0) {
      throw StateError('The student is no longer saved.');
    }
    _touchEverything();
  }

  /// Brings a student back from the Trash with everything they had: the same
  /// row, so the picture, the promotion record, the achievements and the
  /// registry number are simply visible again, under the same id.
  ///
  /// The number never needs to be reassigned: it was reserved for them the whole
  /// time, so nobody else can be holding it.
  Future<void> restoreFromTrash(int id) async {
    final db = await AppDatabase.instance.database;
    final changed = await db.update(
      _table,
      {'deleted_at': ''},
      where: "id = ? AND deleted_at <> ''",
      whereArgs: [id],
    );
    if (changed == 0) {
      throw StateError('The student is no longer in the Trash.');
    }
    _touchEverything();
  }

  /// Removes a student from the database for good, together with their
  /// achievements and their promotion record.
  ///
  /// Only a student who is in the Trash can be removed this way, so a wrong id
  /// can never delete somebody who is still in the registry. The related rows
  /// are deleted explicitly, in the same transaction, instead of relying on the
  /// cascade alone.
  ///
  /// This is the one action that closes a gap in the registry numbers: the
  /// number the student held is passed to the student added after them, who
  /// passes theirs to the next one, and so on — active students and students in
  /// the Trash alike, each keeping their place in the order.
  Future<void> deletePermanently(int id) async {
    final db = await AppDatabase.instance.database;
    final removed = await db.transaction((txn) async {
      final inTrash = await txn.query(
        _table,
        columns: ['id'],
        where: "id = ? AND deleted_at <> ''",
        whereArgs: [id],
        limit: 1,
      );
      if (inTrash.isEmpty) return false;
      await txn.delete('achievements', where: 'student_id = ?', whereArgs: [id]);
      await txn.delete('promotions', where: 'student_id = ?', whereArgs: [id]);
      await txn.delete(_table, where: 'id = ?', whereArgs: [id]);
      await _renumberStudents(txn);
      return true;
    });
    if (!removed) {
      throw StateError('The student is no longer in the Trash.');
    }
    _touchEverything();
  }

  /// The students in the Trash, the most recently deleted first, each with the
  /// number of records that are waiting with them.
  Future<List<TrashedStudent>> loadTrash() async {
    final db = await AppDatabase.instance.database;
    final columns = [for (final column in _listColumns) 's.$column'].join(', ');
    final rows = await db.rawQuery('''
SELECT $columns, s.deleted_at,
  (SELECT COUNT(*) FROM promotions p WHERE p.student_id = s.id)
    AS promotion_count,
  (SELECT COUNT(*) FROM achievements a WHERE a.student_id = s.id)
    AS achievement_count
FROM students s
WHERE s.deleted_at <> ''
ORDER BY s.deleted_at DESC, s.id DESC
''');
    return [
      for (final row in rows)
        TrashedStudent(
          student: Student.fromMap(row),
          deletedAt: DateTime.tryParse(row['deleted_at'] as String? ?? ''),
          promotionCount: row['promotion_count'] as int? ?? 0,
          achievementCount: row['achievement_count'] as int? ?? 0,
        ),
    ];
  }

  /// The Trash changes what the student, promotion and achievement lists show,
  /// and a permanent delete changes the numbers they display, so all three
  /// revision counters move together.
  static void _touchEverything() {
    revision++;
    PromotionStorage.revision++;
    AchievementStorage.revision++;
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
      await _insertSnapshot(txn, deleted.student);
      final promotion = deleted.promotion;
      if (promotion != null) await txn.insert('promotions', promotion);
      for (final achievement in deleted.achievements) {
        await txn.insert('achievements', achievement);
      }
    });
    revision++;
    // Restore writes the promotion and achievement rows back in directly, not
    // through their own storage classes, so their revision counters need the
    // same bump as delete's.
    PromotionStorage.revision++;
    AchievementStorage.revision++;
  }

  /// Puts one snapshotted student row back, id and registry number included.
  ///
  /// Should the registry number have been taken by somebody else after the
  /// deletion, the student comes back under the next free number instead of
  /// being refused. Losing the number is recoverable; losing the student, their
  /// belt and their awards is not.
  Future<void> _insertSnapshot(
    DatabaseExecutor db,
    Map<String, Object?> row,
  ) async {
    try {
      await db.insert(_table, row);
      return;
    } on DatabaseException catch (error) {
      if (!error.isUniqueConstraintError()) rethrow;
      final number = _formatStudentNo(await _highestNumber(db) + 1);
      await db.insert(_table, {...row, 'student_no': number});
    }
  }

  /// Re-encodes the pictures saved before the compact copy existed.
  ///
  /// A row written by an older version keeps its full-size photo in
  /// `photo_base64`, which is what made those registries expensive to open.
  /// Here the original is moved to `photo_full_base64` and the compact column
  /// gets a small copy of it, so the pages become cheap again without the
  /// picture being lost. The original is stored before the compact one, each
  /// update in its own transaction, so an interrupted run can never leave a
  /// student without a picture.
  ///
  /// Only rows that have no separate original yet are looked at. A row saved by
  /// the current version always carries one (the upload form writes both
  /// copies), and a row this method already converted carries one too, so
  /// neither is decoded again: after the first run this is one cheap query
  /// per launch, not a decode of every large picture.
  ///
  /// [StartupGate] runs this once per launch, before the first screen reads
  /// the registry.
  ///
  /// Returns how many students were shrunk.
  Future<int> shrinkLargePhotos() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      _table,
      columns: ['id', 'photo_base64', 'photo_full_base64'],
      where: "length(photo_base64) > ? AND photo_full_base64 = ''",
      whereArgs: [_largePhotoLength],
    );

    var shrunk = 0;
    for (final row in rows) {
      final id = row['id'] as int?;
      final original = row['photo_base64'] as String? ?? '';
      if (id == null || original.isEmpty) continue;

      // A value no codec accepts is left exactly as it is, never replaced.
      final bytes = Student.decodePhoto(original);
      if (bytes == null) continue;
      final compact = await PhotoProcessor.compact(bytes);
      if (compact == null) continue;

      final compactBase64 = base64Encode(compact);
      // A picture that would not actually get smaller is not worth rewriting.
      if (compactBase64.length >= original.length) continue;

      final stored = row['photo_full_base64'] as String? ?? '';
      await db.transaction((txn) async {
        if (stored.isEmpty) {
          await txn.update(
            _table,
            {'photo_full_base64': original},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        await txn.update(
          _table,
          {'photo_base64': compactBase64},
          where: 'id = ?',
          whereArgs: [id],
        );
      });
      shrunk++;
    }
    // The compact pictures changed under any page that already read them.
    if (shrunk > 0) revision++;
    return shrunk;
  }
}
