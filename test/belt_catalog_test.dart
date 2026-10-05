import 'package:flutter_test/flutter_test.dart';

import 'package:tkd_app/models/belt.dart';

void main() {
  test('the Belt menu lists the grades in the required order', () {
    expect(BeltCatalog.grades, const [
      '3rd Dan Blackbelt',
      '2nd Dan Blackbelt',
      '1st Dan Blackbelt',
      '1st Grade Brown',
      '2nd Grade Brown',
      '3rd Grade Red',
      '4th Grade Red',
      '5th Grade Blue',
      '6th Grade Blue',
      '7th Grade Yellow',
      '8th Grade Yellow',
      '9th Grade White',
    ]);

    // The list order is also the sort order of the promotion list.
    expect(
      BeltCatalog.rankOf('1st Dan Blackbelt'),
      lessThan(BeltCatalog.rankOf('9th Grade White')),
    );
    expect(
      BeltCatalog.rankOf('3rd Dan Blackbelt'),
      lessThan(BeltCatalog.rankOf('1st Dan Blackbelt')),
    );

    // A new record still starts on the entry-level belt.
    expect(BeltCatalog.defaultGrade, '9th Grade White');
    expect(BeltCatalog.grades, contains(BeltCatalog.defaultGrade));
  });

  test('there is one Quick Card per belt colour, strongest first', () {
    expect(
      [for (final group in BeltCatalog.groups) group.label],
      const [
        'Black Belts',
        'Brown Belts',
        'Red Belts',
        'Blue Belts',
        'Yellow Belts',
        'White Belts',
      ],
    );
  });

  test('every Dan rank is counted as a Black Belt', () {
    final black = BeltCatalog.groups.first;
    for (final grade in const [
      '1st Dan Blackbelt',
      '2nd Dan Blackbelt',
      '3rd Dan Blackbelt',
    ]) {
      expect(BeltCatalog.familyOf(grade), same(black));
    }

    // Mixed ranks of the same colour collapse onto the one card.
    expect(
      black.countIn(const [
        '1st Dan Blackbelt',
        '3rd Dan Blackbelt',
        '9th Grade White',
      ]),
      2,
    );
  });

  test('both Brown grades are counted as a Brown Belt', () {
    final brown = BeltCatalog.familyOf('1st Grade Brown');
    expect(brown, isNotNull);
    expect(brown!.label, 'Brown Belts');
    expect(BeltCatalog.familyOf('2nd Grade Brown'), same(brown));
    expect(brown.grades, ['1st Grade Brown', '2nd Grade Brown']);
  });

  test('every grade belongs to exactly one colour', () {
    final seen = <String>{};
    for (final group in BeltCatalog.groups) {
      for (final grade in group.grades) {
        expect(seen.add(grade), isTrue, reason: '$grade is listed twice');
        expect(BeltCatalog.familyOf(grade), same(group));
        expect(BeltCatalog.grades, contains(grade));
      }
    }
    // No grade is left out of the Quick Cards either.
    expect(seen, BeltCatalog.grades.toSet());
  });

  test('a colour nobody holds counts zero', () {
    for (final group in BeltCatalog.groups) {
      expect(group.countIn(const <String>[]), 0);
    }
    expect(BeltCatalog.groups.first.countIn(const ['9th Grade White']), 0);
  });

  test('belts recorded before the curriculum change keep counting', () {
    expect(BeltCatalog.normalize('White Belt'), '9th Grade White');
    expect(BeltCatalog.normalize('Red Belt'), '4th Grade Red');
    expect(BeltCatalog.normalize('1st Dan'), '1st Dan Blackbelt');
    expect(BeltCatalog.normalize('3rd Dan'), '3rd Dan Blackbelt');
    // A grade already in the curriculum is left untouched.
    expect(BeltCatalog.normalize('2nd Grade Brown'), '2nd Grade Brown');
    // Green has no replacement, so it stays visible as an unassigned belt.
    expect(BeltCatalog.normalize('Green Belt'), 'Green Belt');
    expect(BeltCatalog.familyOf('Green Belt'), isNull);
  });

  test('unknown belts sort after every grade', () {
    expect(BeltCatalog.rankOf('Green Belt'), BeltCatalog.grades.length);
  });
}
