/// The belt curriculum and the colour families used by the Promotion page.
///
/// Grades of the same colour belong to one [BeltGroup], so the Quick Cards
/// always show a single card per colour: 1st, 2nd and 3rd Dan Blackbelt are
/// all counted as "Black Belts", and 1st and 2nd Grade Brown are both counted
/// as "Brown Belts".
class BeltCatalog {
  const BeltCatalog._();

  /// Every selectable belt grade, highest rank first. This is the order of the
  /// Belt dropdown and of the grouped promotion list.
  static const List<String> grades = [
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
  ];

  /// The belt the Promotion form opens on for a new record: the entry-level
  /// grade, independent of where it sits in [grades].
  static const String defaultGrade = '9th Grade White';

  /// The six belt colours shown as Quick Cards, strongest belt first: the
  /// order the cards are displayed in.
  static const List<BeltGroup> groups = [
    BeltGroup(
      label: 'Black Belts',
      colorValue: 0xFF111111,
      grades: ['1st Dan Blackbelt', '2nd Dan Blackbelt', '3rd Dan Blackbelt'],
    ),
    BeltGroup(
      label: 'Brown Belts',
      colorValue: 0xFF6D4C41,
      grades: ['1st Grade Brown', '2nd Grade Brown'],
    ),
    BeltGroup(
      label: 'Red Belts',
      colorValue: 0xFFDC2626,
      grades: ['3rd Grade Red', '4th Grade Red'],
    ),
    BeltGroup(
      label: 'Blue Belts',
      colorValue: 0xFF2563EB,
      grades: ['5th Grade Blue', '6th Grade Blue'],
    ),
    BeltGroup(
      label: 'Yellow Belts',
      colorValue: 0xFFFACC15,
      grades: ['7th Grade Yellow', '8th Grade Yellow'],
    ),
    BeltGroup(
      label: 'White Belts',
      colorValue: 0xFFF5F5F5,
      grades: ['9th Grade White'],
    ),
  ];

  /// The colour family [belt] belongs to, or null when the value is not part
  /// of the curriculum (for example a belt name saved by an older version).
  static BeltGroup? familyOf(String belt) {
    for (final group in groups) {
      if (group.contains(belt)) return group;
    }
    return null;
  }

  /// Position of [belt] in [grades]; unknown values sort after every grade.
  static int rankOf(String belt) {
    final index = grades.indexOf(belt);
    return index == -1 ? grades.length : index;
  }

  /// Maps belt values written by earlier versions of the app onto the grade
  /// that replaced them, so records saved before the curriculum change still
  /// line up with the dropdown and with their Quick Card.
  static String normalize(String belt) => _legacyGrades[belt] ?? belt;

  /// Belt names used before the grade-based curriculum. "Green Belt" has no
  /// replacement and is deliberately absent: it stays visible under the
  /// "Unassigned Belt" heading instead of being counted as another colour.
  static const Map<String, String> _legacyGrades = {
    'White Belt': '9th Grade White',
    'Yellow Belt': '8th Grade Yellow',
    'Blue Belt': '6th Grade Blue',
    'Brown Belt': '2nd Grade Brown',
    'Red Belt': '4th Grade Red',
    'Black Belt': '1st Dan Blackbelt',
    '1st Dan': '1st Dan Blackbelt',
    '2nd Dan': '2nd Dan Blackbelt',
    '3rd Dan': '3rd Dan Blackbelt',
  };
}

/// One belt colour family: the Quick Card label, the belt colour shared by the
/// card and the grade heading, and every grade that counts towards it.
class BeltGroup {
  const BeltGroup({
    required this.label,
    required this.grades,
    required this.colorValue,
  });

  /// Card label, e.g. `Black Belts`.
  final String label;

  /// Grades of this colour, in promotion order. Every Dan rank sits under the
  /// black family, and both Brown grades under the brown family, so one card
  /// covers the whole colour.
  final List<String> grades;

  /// ARGB value of the belt colour. Kept beside the grades so the card fill
  /// and the grade heading can never drift apart.
  final int colorValue;

  /// Whether [belt] belongs to this colour family.
  bool contains(String belt) => grades.contains(belt);

  /// How many of [belts] belong to this colour family.
  int countIn(Iterable<String> belts) {
    var count = 0;
    for (final belt in belts) {
      if (contains(belt)) count++;
    }
    return count;
  }
}
