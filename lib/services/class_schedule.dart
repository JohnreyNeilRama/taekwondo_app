import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// The weekdays the club holds classes on, set by the owner (for example
/// Monday, Wednesday and Friday).
///
/// Whether a class was held on a day is a fact the owner declares, not
/// something worked out from who happened to be scanned: if nobody was scanned
/// on a class day, that is a day everyone was absent, not a day without class.
///
/// Days are numbered like [DateTime.weekday]: Monday is 1 and Sunday is 7. The
/// schedule is kept in `app_meta` as one line of numbers (`1,3,5`). A schedule
/// the owner never set is `null`, which is different from a saved schedule with
/// no days at all: the app never guesses on the owner's behalf.
class ClassSchedule {
  /// Key the schedule is kept under in `app_meta`.
  static const String metaKey = 'schedule.class_days';

  /// Bumped by every save, so a page that shows the schedule can tell whether it
  /// changed since it last read.
  static int revision = 0;

  static const int monday = 1;
  static const int sunday = 7;

  /// The class days in stored text, or null when [text] is null. Anything that
  /// is not a weekday number is ignored, so a damaged value cannot break the
  /// attendance screen.
  static Set<int>? parse(String? text) {
    if (text == null) return null;
    return {
      for (final part in text.split(','))
        ?_weekday(int.tryParse(part.trim())),
    };
  }

  /// The class days in a decoded backup value (a list of numbers), or null when
  /// the value is missing or is not a list.
  static Set<int>? fromList(Object? value) {
    if (value is! List) return null;
    return {
      for (final item in value)
        ?_weekday(item is num ? item.toInt() : int.tryParse('$item')),
    };
  }

  static int? _weekday(int? value) =>
      value != null && value >= monday && value <= sunday ? value : null;

  /// Whether a class is held on [day] under [days]. False when no schedule has
  /// been set.
  static bool isClassDay(Set<int>? days, DateTime day) =>
      days?.contains(day.weekday) ?? false;

  /// The saved class days read through [db] (the database or a transaction), or
  /// null when the owner never set them.
  static Future<Set<int>?> readFrom(DatabaseExecutor db) async {
    final rows = await db.query(
      AppDatabase.metaTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [metaKey],
    );
    if (rows.isEmpty) return null;
    return parse(rows.first['value'] as String?);
  }

  /// Each day of [month] that is a class day under [days], in order.
  static Iterable<DateTime> classDaysOfMonth(Set<int>? days, DateTime month) sync* {
    if (days == null || days.isEmpty) return;
    final last = DateTime(month.year, month.month + 1, 0).day;
    for (var day = 1; day <= last; day++) {
      final date = DateTime(month.year, month.month, day);
      if (days.contains(date.weekday)) yield date;
    }
  }

  /// Saves [weekdays] through [db], replacing what was there.
  static Future<void> writeTo(DatabaseExecutor db, Set<int> weekdays) async {
    final days = [
      for (final day in weekdays)
        if (_weekday(day) != null) day,
    ]..sort();
    await db.insert(AppDatabase.metaTable, {
      'key': metaKey,
      'value': days.join(','),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    revision++;
  }

  /// The saved class days, or null when the owner never set them.
  Future<Set<int>?> load() async {
    final db = await AppDatabase.instance.database;
    return readFrom(db);
  }

  /// Saves the class days. An empty set is a real answer ("no classes"), not
  /// the same as never having set them.
  Future<void> save(Set<int> weekdays) async {
    final db = await AppDatabase.instance.database;
    await writeTo(db, weekdays);
  }
}
