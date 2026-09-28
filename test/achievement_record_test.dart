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

  test('a record survives a JSON round trip', () {
    const record = AchievementRecord(
      id: '42',
      studentNo: 'TKD-0001',
      studentName: 'Nguyen Van A',
      date: '03/10/2026',
      event: 'National Tournament',
      award: 'Gold',
    );

    final restored = AchievementRecord.fromJson(record.toJson());

    expect(restored.id, '42');
    expect(restored.studentNo, 'TKD-0001');
    expect(restored.studentName, 'Nguyen Van A');
    expect(restored.date, '03/10/2026');
    expect(restored.event, 'National Tournament');
    expect(restored.award, 'Gold');
    expect(restored.medal, same(Award.gold));
  });

  test('a corrupt record falls back to empty values', () {
    final restored = AchievementRecord.fromJson(const {});
    expect(restored.id, '');
    expect(restored.studentNo, '');
    expect(restored.event, '');
    expect(restored.medal, isNull);
  });

  test('copyWith keeps the identity that links it to the student', () {
    const record = AchievementRecord(
      id: '7',
      studentNo: 'TKD-0002',
      award: 'Silver',
    );

    final renamed = record.copyWith(
      studentName: 'Tran Thi B',
      event: 'Regionals',
    );

    expect(renamed.id, '7');
    expect(renamed.studentNo, 'TKD-0002');
    expect(renamed.award, 'Silver');
    expect(renamed.studentName, 'Tran Thi B');
    expect(renamed.event, 'Regionals');
  });
}
