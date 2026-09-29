import 'package:flutter_test/flutter_test.dart';

import 'package:tkd_app/models/achievement_record.dart';

void main() {
  test('the Achievement menu offers Gold, Silver and Bronze', () {
    expect(
      [for (final award in Award.all) award.label],
      const ['Gold', 'Silver', 'Bronze'],
    );
  });

  test('a medal label maps back to its award, unknown values to null', () {
    expect(Award.fromLabel('Gold'), same(Award.gold));
    expect(Award.fromLabel('Silver'), same(Award.silver));
    expect(Award.fromLabel('Bronze'), same(Award.bronze));
    expect(Award.fromLabel('Platinum'), isNull);
    expect(Award.fromLabel(''), isNull);
  });

  test('the medals are coloured differently', () {
    final colors = [for (final award in Award.all) award.colorValue];
    expect(colors.toSet(), hasLength(3));
    final tints = [for (final award in Award.all) award.tintValue];
    expect(tints.toSet(), hasLength(3));
  });

  test('a record survives a database round trip', () {
    const record = AchievementRecord(
      studentId: 7,
      date: '03/10/2026',
      event: 'National Tournament',
      award: 'Gold',
    );

    // The id comes from the row and the registry number and name from the
    // JOIN with the students table, exactly as the storage layer reads them.
    final restored = AchievementRecord.fromMap({
      'id': 42,
      'student_no': 'TKD-0007',
      'student_name': 'Nguyen Van A',
      ...record.toMap(),
    });

    expect(restored.id, 42);
    expect(restored.studentId, 7);
    expect(restored.studentNo, 'TKD-0007');
    expect(restored.studentName, 'Nguyen Van A');
    expect(restored.date, '03/10/2026');
    expect(restored.event, 'National Tournament');
    expect(restored.award, 'Gold');
    expect(restored.medal, same(Award.gold));
  });

  test('only the stored columns are written to the row', () {
    const record = AchievementRecord(
      id: 42,
      studentId: 7,
      studentNo: 'TKD-0007',
      studentName: 'Nguyen Van A',
      date: '03/10/2026',
      event: 'National Tournament',
      award: 'Gold',
    );

    expect(record.toMap(), {
      'student_id': 7,
      'achievement_date': '03/10/2026',
      'event': 'National Tournament',
      'award': 'Gold',
    });
  });

  test('a corrupt row falls back to empty values', () {
    final restored = AchievementRecord.fromMap(const {});
    expect(restored.id, isNull);
    expect(restored.studentId, 0);
    expect(restored.studentNo, '');
    expect(restored.event, '');
    expect(restored.medal, isNull);
  });

  test('copyWith keeps the identity that links it to the student', () {
    const record = AchievementRecord(
      id: 7,
      studentId: 2,
      studentNo: 'TKD-0002',
      award: 'Silver',
    );

    final renamed = record.copyWith(
      studentName: 'Tran Thi B',
      event: 'Regionals',
    );

    expect(renamed.id, 7);
    expect(renamed.studentId, 2);
    expect(renamed.studentNo, 'TKD-0002');
    expect(renamed.award, 'Silver');
    expect(renamed.studentName, 'Tran Thi B');
    expect(renamed.event, 'Regionals');
  });
}
