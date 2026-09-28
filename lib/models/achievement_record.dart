/// Medal an achievement can win, with the colours used for its chips.
class Award {
  const Award({
    required this.label,
    required this.colorValue,
    required this.tintValue,
  });

  /// Award name shown in the form and on the chips, e.g. `Gold`.
  final String label;

  /// ARGB value of the medal colour, used for the chip text and icon.
  final int colorValue;

  /// ARGB value of the soft background the chip is filled with.
  final int tintValue;

  static const Award gold = Award(
    label: 'Gold',
    colorValue: 0xFFB45309,
    tintValue: 0xFFFEF3C7,
  );
  static const Award silver = Award(
    label: 'Silver',
    colorValue: 0xFF4B5563,
    tintValue: 0xFFE5E7EB,
  );
  static const Award bronze = Award(
    label: 'Bronze',
    colorValue: 0xFFC2410C,
    tintValue: 0xFFFFEDD5,
  );

  /// The awards offered by the Achievement dropdown, best medal first.
  static const List<Award> all = [gold, silver, bronze];

  /// The award called [label], or null for an empty / unknown value; keeps a
  /// corrupt stored record visible instead of crashing the screen.
  static Award? fromLabel(String label) {
    for (final award in all) {
      if (award.label == label) return award;
    }
    return null;
  }
}

/// One achievement won by a student.
///
/// Achievements live in their own list and are keyed by [studentNo], so the
/// many records of a student all point at the single student on the Students
/// page without ever duplicating or altering that registry entry.
class AchievementRecord {
  const AchievementRecord({
    required this.id,
    required this.studentNo,
    this.studentName = '',
    this.date = '',
    this.event = '',
    this.award = '',
  });

  /// Unique id, so one student can hold many achievements and each of them
  /// can still be edited, replaced or deleted on its own.
  final String id;

  /// Registry number of the student who won it, e.g. `TKD-0001`.
  final String studentNo;

  /// Cached name, so a record still reads sensibly if the student is renamed.
  /// Refreshed from the registry whenever records are loaded.
  final String studentName;

  /// Stored as `MM/DD/YYYY` to match `Student.birthDate`.
  final String date;

  /// The event the achievement was won at, e.g. `National Tournament`.
  final String event;

  /// One of the [Award] labels; empty while nothing has been picked yet.
  final String award;

  /// The medal for [award], or null when nothing valid is stored.
  Award? get medal => Award.fromLabel(award);

  AchievementRecord copyWith({
    String? studentName,
    String? date,
    String? event,
    String? award,
  }) => AchievementRecord(
    id: id,
    studentNo: studentNo,
    studentName: studentName ?? this.studentName,
    date: date ?? this.date,
    event: event ?? this.event,
    award: award ?? this.award,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'studentNo': studentNo,
    'studentName': studentName,
    'date': date,
    'event': event,
    'award': award,
  };

  /// Rebuilds a record from JSON, falling back to empty strings so a corrupt
  /// entry can never crash the screen.
  factory AchievementRecord.fromJson(Map<String, dynamic> json) =>
      AchievementRecord(
        id: json['id'] as String? ?? '',
        studentNo: json['studentNo'] as String? ?? '',
        studentName: json['studentName'] as String? ?? '',
        date: json['date'] as String? ?? '',
        event: json['event'] as String? ?? '',
        award: json['award'] as String? ?? '',
      );
}
