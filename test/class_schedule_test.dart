import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/class_schedule.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.debugReset();
    AppDatabase.debugOverridePath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await AppDatabase.debugReset();
  });

  test('parse keeps weekday numbers and ignores the rest', () {
    expect(ClassSchedule.parse(null), isNull);
    expect(ClassSchedule.parse('1,3,5'), {1, 3, 5});
    expect(ClassSchedule.parse(' 7, 0, 8, 2 '), {2, 7});
    expect(ClassSchedule.parse(''), isEmpty);
  });

  test('fromList reads a backup value', () {
    expect(ClassSchedule.fromList(null), isNull);
    expect(ClassSchedule.fromList('1,3,5'), isNull);
    expect(ClassSchedule.fromList([1, 3, 5]), {1, 3, 5});
    expect(ClassSchedule.fromList([1, '3', 9]), {1, 3});
  });

  test('a class day is a weekday the owner marked, never a guess', () {
    expect(ClassSchedule.isClassDay(null, DateTime(2020, 3, 2)), isFalse);
    expect(ClassSchedule.isClassDay({}, DateTime(2020, 3, 2)), isFalse);
    expect(ClassSchedule.isClassDay({1, 3, 5}, DateTime(2020, 3, 2)), isTrue);
    expect(ClassSchedule.isClassDay({1, 3, 5}, DateTime(2020, 3, 3)), isFalse);
  });

  test('the saved schedule is what the owner wrote, including none', () async {
    final schedule = ClassSchedule();
    expect(await schedule.load(), isNull);

    await schedule.save({5, 1, 3, 99});
    expect(await schedule.load(), {1, 3, 5});

    await schedule.save({});
    expect(await schedule.load(), isEmpty);
  });
}
