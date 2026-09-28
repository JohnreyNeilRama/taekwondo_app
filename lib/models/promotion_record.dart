/// Belt and promotion information for one student.
///
/// Promotion records live in their own list and are keyed by [studentNo],
/// so a record always stays attached to the same student without
/// duplicating or altering the student registry itself.
class PromotionRecord {
  const PromotionRecord({
    required this.studentNo,
    this.studentName = '',
    this.belt = '',
    this.lastPromotionDate = '',
  });

  /// Registry number of the student this record belongs to, e.g. `TKD-0001`.
  final String studentNo;

  /// Cached name, so a record still reads sensibly if the student is
  /// renamed. Refreshed from the registry whenever records are loaded.
  final String studentName;

  /// The student's current / newest belt, e.g. `Red Belt`.
  final String belt;

  /// Stored as `MM/DD/YYYY` to match `Student.birthDate`.
  final String lastPromotionDate;

  PromotionRecord copyWith({
    String? studentName,
    String? belt,
    String? lastPromotionDate,
  }) => PromotionRecord(
    studentNo: studentNo,
    studentName: studentName ?? this.studentName,
    belt: belt ?? this.belt,
    lastPromotionDate: lastPromotionDate ?? this.lastPromotionDate,
  );

  Map<String, dynamic> toJson() => {
    'studentNo': studentNo,
    'studentName': studentName,
    'belt': belt,
    'lastPromotionDate': lastPromotionDate,
  };

  /// Rebuilds a record from JSON, falling back to empty strings so a
  /// corrupt entry can never crash the screen.
  factory PromotionRecord.fromJson(Map<String, dynamic> json) =>
      PromotionRecord(
        studentNo: json['studentNo'] as String? ?? '',
        studentName: json['studentName'] as String? ?? '',
        belt: json['belt'] as String? ?? '',
        lastPromotionDate: json['lastPromotionDate'] as String? ?? '',
      );
}
