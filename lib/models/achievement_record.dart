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
/// A student can hold many of these, each linked by [studentId] — the
/// `students.id` primary key — so all the awards of one student follow the
/// single registry entry and a rename can never duplicate it. [studentNo] and
/// [studentName] are read from the registry by the storage layer's JOIN: they
/// are shown on screen but never saved on this record.
class AchievementRecord {
  const AchievementRecord({
    this.id,
    required this.studentId,
    this.studentNo = '',
    this.studentName = '',
    this.date = '',
    this.event = '',
    this.award = '',
  });

  /// Primary key of the `achievements` row; null for a record the database has
  /// not saved yet. The id is what lets one student hold many achievements and
  /// still have each of them edited, replaced or deleted on its own.
  final int? id;

  /// The `students.id` this achievement belongs to.
  final int studentId;

  /// Registry number of the student who won it, e.g. `TKD-0001`, filled by the
  /// JOIN from the registry.
  final String studentNo;

  /// The student's name, filled by the JOIN from the registry.
  final String studentName;

  /// Stored as `MM/DD/YYYY` to match `Student.birthDate`.
  /// Saved in the `achievement_date` column.
  final String date;

  /// The event the achievement was won at, e.g. `National Tournament`.
  final String event;

  /// One of the [Award] labels; empty while nothing has been picked yet.
  final String award;

  /// The medal for [award], or null when nothing valid is stored.
  Award? get medal => Award.fromLabel(award);

  /// Copy of this record with the id the database assigned to it.
  AchievementRecord withId(int id) => AchievementRecord(
    id: id,
    studentId: studentId,
    studentNo: studentNo,
    studentName: studentName,
    date: date,
    event: event,
    award: award,
  );

  AchievementRecord copyWith({
    String? studentName,
    String? date,
    String? event,
    String? award,
  }) => AchievementRecord(
    id: id,
    studentId: studentId,
    studentNo: studentNo,
    studentName: studentName ?? this.studentName,
    date: date ?? this.date,
    event: event ?? this.event,
    award: award ?? this.award,
  );

  /// The row this record becomes in the `achievements` table: the student is
  /// referenced by id, and the display fields are deliberately left out.
  Map<String, Object?> toMap() => {
    'student_id': studentId,
    'achievement_date': date,
    'event': event,
    'award': award,
  };

  /// Rebuilds a record from one `achievements` row joined with its student, so
  /// the registry number and the name always come from the registry itself.
  factory AchievementRecord.fromMap(Map<String, Object?> map) =>
      AchievementRecord(
        id: map['id'] as int?,
        studentId: map['student_id'] as int? ?? 0,
        studentNo: map['student_no'] as String? ?? '',
        studentName: map['student_name'] as String? ?? '',
        date: map['achievement_date'] as String? ?? '',
        event: map['event'] as String? ?? '',
        award: map['award'] as String? ?? '',
      );
}
