/// Belt and promotion information for one student.
///
/// A student holds at most one of these, linked by [studentId] — the
/// `students.id` primary key — so renaming a student can never orphan or
/// duplicate their promotion. [studentNo] and [studentName] are read from the
/// registry by the storage layer's JOIN: they are shown on screen but never
/// saved on this record.
class PromotionRecord {
  const PromotionRecord({
    this.id,
    required this.studentId,
    this.studentNo = '',
    this.studentName = '',
    this.belt = '',
    this.lastPromotionDate = '',
  });

  /// Primary key of the `promotions` row; null until the record is saved.
  final int? id;

  /// The `students.id` this record belongs to. Every save goes through this
  /// id, so re-recording a student updates their row instead of adding one.
  final int studentId;

  /// Registry number of the student, e.g. `TKD-0001`. Filled by the JOIN.
  final String studentNo;

  /// The student's name, filled by the JOIN, so it always matches the registry
  /// even after a rename.
  final String studentName;

  /// The student's current / newest belt, e.g. `Red Belt`.
  final String belt;

  /// Stored as `MM/DD/YYYY` to match `Student.birthDate`.
  final String lastPromotionDate;

  /// Copy of this record with the id the database assigned to it.
  PromotionRecord withId(int id) => PromotionRecord(
    id: id,
    studentId: studentId,
    studentNo: studentNo,
    studentName: studentName,
    belt: belt,
    lastPromotionDate: lastPromotionDate,
  );

  PromotionRecord copyWith({
    String? studentName,
    String? belt,
    String? lastPromotionDate,
  }) => PromotionRecord(
    id: id,
    studentId: studentId,
    studentNo: studentNo,
    studentName: studentName ?? this.studentName,
    belt: belt ?? this.belt,
    lastPromotionDate: lastPromotionDate ?? this.lastPromotionDate,
  );

  /// The row this record becomes in the `promotions` table: the student is
  /// referenced by id, and the display fields are deliberately left out.
  Map<String, Object?> toMap() => {
    'student_id': studentId,
    'belt': belt,
    'last_promotion_date': lastPromotionDate,
  };

  /// Rebuilds a record from one `promotions` row joined with its student, so
  /// the registry number and the name always come from the registry itself.
  factory PromotionRecord.fromMap(Map<String, Object?> map) => PromotionRecord(
    id: map['id'] as int?,
    studentId: map['student_id'] as int? ?? 0,
    studentNo: map['student_no'] as String? ?? '',
    studentName: map['student_name'] as String? ?? '',
    belt: map['belt'] as String? ?? '',
    lastPromotionDate: map['last_promotion_date'] as String? ?? '',
  );
}

/// One belt a student held before their current one, with the date they were
/// promoted to it.
///
/// [PromotionStorage.saveForStudent] writes one of these every time a
/// student's belt changes, before the current belt is overwritten, so a
/// promotion never erases the belt that came before it.
class PromotionHistoryEntry {
  const PromotionHistoryEntry({
    this.id,
    required this.studentId,
    this.belt = '',
    this.promotionDate = '',
    this.recordedAt = '',
  });

  /// Primary key of the `promotion_history` row; null until it is saved.
  final int? id;

  /// The `students.id` this entry belongs to.
  final int studentId;

  /// The belt the student held, e.g. `9th Grade White`.
  final String belt;

  /// The date the student was promoted to [belt], as `MM/DD/YYYY`; empty when
  /// none was recorded.
  final String promotionDate;

  /// When the entry was archived, as local-time ISO 8601 text. Used to keep
  /// entries in order when their promotion dates are missing or equal.
  final String recordedAt;

  factory PromotionHistoryEntry.fromMap(Map<String, Object?> map) =>
      PromotionHistoryEntry(
        id: map['id'] as int?,
        studentId: map['student_id'] as int? ?? 0,
        belt: map['belt'] as String? ?? '',
        promotionDate: map['promotion_date'] as String? ?? '',
        recordedAt: map['recorded_at'] as String? ?? '',
      );
}
