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

  /// Key the cancelled training dates are kept under in `app_meta`.
  static const String cancelledMetaKey = 'schedule.cancelled_dates';

  /// Bumped by every save, so a page that shows the schedule can tell whether it
  /// changed since it last read.
  static int revision = 0;

  static const int monday = 1;
  static const int sunday = 7;

  static final RegExp _dateShape = RegExp(r'^\d{4}-\d{2}-\d{2}$');

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

  /// The local day as `yyyy-mm-dd`, the shape cancelled dates are stored in.
  static String dayKey(DateTime moment) {
    final year = moment.year.toString().padLeft(4, '0');
    final month = moment.month.toString().padLeft(2, '0');
    final day = moment.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Cancelled training days in stored text. Anything that is not a calendar
  /// day is ignored.
  static Set<String> parseDates(String? text) {
    if (text == null || text.isEmpty) return {};
    return {
      for (final part in text.split(','))
        if (_dateShape.hasMatch(part.trim())) part.trim(),
    };
  }

  /// Cancelled training days in a decoded backup value, or null when the value
  /// is missing or is not a list.
  static Set<String>? fromDateList(Object? value) {
    if (value is! List) return null;
    return {
      for (final item in value)
        if (_dateShape.hasMatch('$item'.trim())) '$item'.trim(),
    };
  }

  /// Whether [day] is marked training cancelled.
  static bool isCancelled(Set<String> cancelled, DateTime day) =>
      cancelled.contains(dayKey(day));

  /// Whether a class is held on [day] under [days]. False when no schedule has
  /// been set, and false when [day] is training cancelled: a cancelled date
  /// overrides the weekday schedule.
  static bool isClassDay(
    Set<int>? days,
    DateTime day, {
    Set<String> cancelled = const {},
  }) {
    if (isCancelled(cancelled, day)) return false;
    return days?.contains(day.weekday) ?? false;
  }

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

  /// Each day of [month] that is a class day under [days], in order. Cancelled
  /// training days are left out.
  static Iterable<DateTime> classDaysOfMonth(
    Set<int>? days,
    DateTime month, {
    Set<String> cancelled = const {},
  }) sync* {
    if (days == null || days.isEmpty) return;
    final last = DateTime(month.year, month.month + 1, 0).day;
    for (var day = 1; day <= last; day++) {
      final date = DateTime(month.year, month.month, day);
      if (isClassDay(days, date, cancelled: cancelled)) yield date;
    }
  }

  /// Day-of-month numbers in [month] that are marked training cancelled.
  static Set<int> cancelledDaysOfMonth(Set<String> cancelled, DateTime month) {
    final prefix =
        '${month.year.toString().padLeft(4, '0')}-'
        '${month.month.toString().padLeft(2, '0')}-';
    return {
      for (final key in cancelled)
        if (key.startsWith(prefix))
          ?int.tryParse(key.substring(8, 10)),
    };
  }

  /// The cancelled training dates read through [db], empty when none are set.
  static Future<Set<String>> readCancelledFrom(DatabaseExecutor db) async {
    final rows = await db.query(
      AppDatabase.metaTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [cancelledMetaKey],
    );
    if (rows.isEmpty) return {};
    return parseDates(rows.first['value'] as String?);
  }

  /// Saves [dates] through [db], replacing what was there.
  static Future<void> writeCancelledTo(
    DatabaseExecutor db,
    Set<String> dates,
  ) async {
    final keys = [
      for (final day in dates)
        if (_dateShape.hasMatch(day)) day,
    ]..sort();
    await db.insert(AppDatabase.metaTable, {
      'key': cancelledMetaKey,
      'value': keys.join(','),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    revision++;
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

  /// The cancelled training dates, empty when none are set.
  Future<Set<String>> loadCancelled() async {
    final db = await AppDatabase.instance.database;
    return readCancelledFrom(db);
  }

  /// Replaces the cancelled training dates with [dates].
  Future<void> saveCancelled(Set<String> dates) async {
    final db = await AppDatabase.instance.database;
    await writeCancelledTo(db, dates);
  }

  /// Marks or clears training cancelled on [day].
  Future<void> setCancelled(DateTime day, bool cancelled) async {
    final db = await AppDatabase.instance.database;
    final dates = await readCancelledFrom(db);
    final key = dayKey(day);
    if (cancelled) {
      dates.add(key);
    } else {
      dates.remove(key);
    }
    await writeCancelledTo(db, dates);
  }
}
