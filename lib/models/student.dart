import 'dart:convert';
import 'dart:typed_data';

/// Student record built from the Taekwondo Information Sheet.
class Student {
  const Student({
    this.id,
    required this.name,
    this.studentNo = '',
    this.nickname = '',
    this.homeAddress = '',
    this.telephoneNos = '',
    this.cellphoneNo = '',
    this.email = '',
    this.birthDate = '',
    this.religion = '',
    this.sex = '',
    this.status = '',
    this.schoolName = '',
    this.gradeYearCourse = '',
    this.companyNameAddress = '',
    this.fatherName = '',
    this.fatherOccupation = '',
    this.fatherOfficeAddress = '',
    this.fatherContactNos = '',
    this.motherName = '',
    this.motherOccupation = '',
    this.motherOfficeAddress = '',
    this.motherContactNos = '',
    this.guardianName = '',
    this.guardianContactNos = '',
    this.previousMartialArts = '',
    this.otherHobbiesSports = '',
    this.healthConditions = '',
    this.photoBase64 = '',
  });

  /// Primary key of the `students` row. Null on a record that has not been
  /// saved yet; filled in by [StudentStorage.insert] and carried through every
  /// edit, so saving a change updates that row instead of adding a new one.
  final int? id;

  final String name;

  /// Registry number shown on the list card, e.g. `TKD-0001`. Minted by the
  /// storage layer when a record is created; kept on edit.
  final String studentNo;
  final String nickname;
  final String homeAddress;
  final String telephoneNos;
  final String cellphoneNo;
  final String email;
  final String birthDate;
  final String religion;
  final String sex;
  final String status;
  final String schoolName;
  final String gradeYearCourse;
  final String companyNameAddress;

  // Parents / Guardian.
  final String fatherName;
  final String fatherOccupation;
  final String fatherOfficeAddress;
  final String fatherContactNos;
  final String motherName;
  final String motherOccupation;
  final String motherOfficeAddress;
  final String motherContactNos;
  final String guardianName;
  final String guardianContactNos;

  // Background questions.
  final String previousMartialArts;
  final String otherHobbiesSports;
  final String healthConditions;

  /// The persisted JPG/PNG bytes, encoded as base64. Keeping this in
  /// the student record associates the photo with the correct account.
  final String photoBase64;

  /// The saved picture as the bytes an `Image` can draw, or null when this
  /// student has no picture — the screens then fall back to the initials.
  ///
  /// Every page draws this same value off the student row, which is what makes
  /// one uploaded picture show up as the avatar of the Students, Promotion and
  /// Achievement lists at once and stay there across restarts.
  Uint8List? get photoBytes => decodePhoto(photoBase64);

  /// Turns the saved `photo_base64` text into image bytes.
  ///
  /// The upload form writes plain base64. A `data:image/png;base64,...` value
  /// is accepted as well, so a row saved in that shape still shows its picture.
  /// Anything that cannot be decoded answers null, and the caller draws the
  /// initials instead — a corrupt row can never break a list.
  static Uint8List? decodePhoto(String photoBase64) {
    if (photoBase64.isEmpty) return null;
    final comma = photoBase64.indexOf(',');
    final encoded = photoBase64.startsWith('data:') && comma != -1
        ? photoBase64.substring(comma + 1)
        : photoBase64;
    if (encoded.isEmpty) return null;
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  String get initials {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Copy of this record with a different [studentNo] (used when the storage
  /// layer stamps a registry number onto a freshly created student).
  Student withStudentNo(String studentNo) => Student(
    id: id,
    name: name,
    studentNo: studentNo,
    nickname: nickname,
    homeAddress: homeAddress,
    telephoneNos: telephoneNos,
    cellphoneNo: cellphoneNo,
    email: email,
    birthDate: birthDate,
    religion: religion,
    sex: sex,
    status: status,
    schoolName: schoolName,
    gradeYearCourse: gradeYearCourse,
    companyNameAddress: companyNameAddress,
    fatherName: fatherName,
    fatherOccupation: fatherOccupation,
    fatherOfficeAddress: fatherOfficeAddress,
    fatherContactNos: fatherContactNos,
    motherName: motherName,
    motherOccupation: motherOccupation,
    motherOfficeAddress: motherOfficeAddress,
    motherContactNos: motherContactNos,
    guardianName: guardianName,
    guardianContactNos: guardianContactNos,
    previousMartialArts: previousMartialArts,
    otherHobbiesSports: otherHobbiesSports,
    healthConditions: healthConditions,
    photoBase64: photoBase64,
  );

  /// Copy of this record carrying the id the database assigned to it.
  Student withId(int id) => Student(
    id: id,
    name: name,
    studentNo: studentNo,
    nickname: nickname,
    homeAddress: homeAddress,
    telephoneNos: telephoneNos,
    cellphoneNo: cellphoneNo,
    email: email,
    birthDate: birthDate,
    religion: religion,
    sex: sex,
    status: status,
    schoolName: schoolName,
    gradeYearCourse: gradeYearCourse,
    companyNameAddress: companyNameAddress,
    fatherName: fatherName,
    fatherOccupation: fatherOccupation,
    fatherOfficeAddress: fatherOfficeAddress,
    fatherContactNos: fatherContactNos,
    motherName: motherName,
    motherOccupation: motherOccupation,
    motherOfficeAddress: motherOfficeAddress,
    motherContactNos: motherContactNos,
    guardianName: guardianName,
    guardianContactNos: guardianContactNos,
    previousMartialArts: previousMartialArts,
    otherHobbiesSports: otherHobbiesSports,
    healthConditions: healthConditions,
    photoBase64: photoBase64,
  );

  /// The row this record becomes in the `students` table. Every one of the 28
  /// sheet columns is written, so an edit can never blank a field out by
  /// leaving it out of the map.
  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'student_no': studentNo,
    'name': name,
    'nickname': nickname,
    'home_address': homeAddress,
    'telephone_nos': telephoneNos,
    'cellphone_no': cellphoneNo,
    'email': email,
    'birth_date': birthDate,
    'religion': religion,
    'sex': sex,
    'status': status,
    'school_name': schoolName,
    'grade_year_course': gradeYearCourse,
    'company_name_address': companyNameAddress,
    'father_name': fatherName,
    'father_occupation': fatherOccupation,
    'father_office_address': fatherOfficeAddress,
    'father_contact_nos': fatherContactNos,
    'mother_name': motherName,
    'mother_occupation': motherOccupation,
    'mother_office_address': motherOfficeAddress,
    'mother_contact_nos': motherContactNos,
    'guardian_name': guardianName,
    'guardian_contact_nos': guardianContactNos,
    'previous_martial_arts': previousMartialArts,
    'other_hobbies_sports': otherHobbiesSports,
    'health_conditions': healthConditions,
    'photo_base64': photoBase64,
  };

  /// Rebuilds a [Student] from one `students` row. Missing or null values fall
  /// back to empty strings, so a partially filled row can never crash the app.
  factory Student.fromMap(Map<String, Object?> map) => Student(
    id: map['id'] as int?,
    name: _text(map['name']),
    studentNo: _text(map['student_no']),
    nickname: _text(map['nickname']),
    homeAddress: _text(map['home_address']),
    telephoneNos: _text(map['telephone_nos']),
    cellphoneNo: _text(map['cellphone_no']),
    email: _text(map['email']),
    birthDate: _text(map['birth_date']),
    religion: _text(map['religion']),
    sex: _text(map['sex']),
    status: _text(map['status']),
    schoolName: _text(map['school_name']),
    gradeYearCourse: _text(map['grade_year_course']),
    companyNameAddress: _text(map['company_name_address']),
    fatherName: _text(map['father_name']),
    fatherOccupation: _text(map['father_occupation']),
    fatherOfficeAddress: _text(map['father_office_address']),
    fatherContactNos: _text(map['father_contact_nos']),
    motherName: _text(map['mother_name']),
    motherOccupation: _text(map['mother_occupation']),
    motherOfficeAddress: _text(map['mother_office_address']),
    motherContactNos: _text(map['mother_contact_nos']),
    guardianName: _text(map['guardian_name']),
    guardianContactNos: _text(map['guardian_contact_nos']),
    previousMartialArts: _text(map['previous_martial_arts']),
    otherHobbiesSports: _text(map['other_hobbies_sports']),
    healthConditions: _text(map['health_conditions']),
    photoBase64: _text(map['photo_base64']),
  );

  /// Reads one text column, tolerating null.
  static String _text(Object? value) => value as String? ?? '';

  /// The JSON shape the versions before the database wrote to
  /// `students_v1.json`. Only the one-time import reads it; the database never
  /// uses it.
  Map<String, dynamic> toJson() => {
    'name': name,
    'studentNo': studentNo,
    'nickname': nickname,
    'homeAddress': homeAddress,
    'telephoneNos': telephoneNos,
    'cellphoneNo': cellphoneNo,
    'email': email,
    'birthDate': birthDate,
    'religion': religion,
    'sex': sex,
    'status': status,
    'schoolName': schoolName,
    'gradeYearCourse': gradeYearCourse,
    'companyNameAddress': companyNameAddress,
    'fatherName': fatherName,
    'fatherOccupation': fatherOccupation,
    'fatherOfficeAddress': fatherOfficeAddress,
    'fatherContactNos': fatherContactNos,
    'motherName': motherName,
    'motherOccupation': motherOccupation,
    'motherOfficeAddress': motherOfficeAddress,
    'motherContactNos': motherContactNos,
    'guardianName': guardianName,
    'guardianContactNos': guardianContactNos,
    'previousMartialArts': previousMartialArts,
    'otherHobbiesSports': otherHobbiesSports,
    'healthConditions': healthConditions,
    'photoBase64': photoBase64,
  };

  /// Rebuilds a [Student] from JSON previously written by [toJson].
  /// Missing or corrupt values fall back to empty strings so a bad
  /// record can never crash the app on startup.
  factory Student.fromJson(Map<String, dynamic> json) => Student(
    name: json['name'] as String? ?? '',
    studentNo: json['studentNo'] as String? ?? '',
    nickname: json['nickname'] as String? ?? '',
    homeAddress: json['homeAddress'] as String? ?? '',
    telephoneNos: json['telephoneNos'] as String? ?? '',
    cellphoneNo: json['cellphoneNo'] as String? ?? '',
    email: json['email'] as String? ?? '',
    birthDate: json['birthDate'] as String? ?? '',
    religion: json['religion'] as String? ?? '',
    sex: json['sex'] as String? ?? '',
    status: json['status'] as String? ?? '',
    schoolName: json['schoolName'] as String? ?? '',
    gradeYearCourse: json['gradeYearCourse'] as String? ?? '',
    companyNameAddress: json['companyNameAddress'] as String? ?? '',
    fatherName: json['fatherName'] as String? ?? '',
    fatherOccupation: json['fatherOccupation'] as String? ?? '',
    fatherOfficeAddress: json['fatherOfficeAddress'] as String? ?? '',
    fatherContactNos: json['fatherContactNos'] as String? ?? '',
    motherName: json['motherName'] as String? ?? '',
    motherOccupation: json['motherOccupation'] as String? ?? '',
    motherOfficeAddress: json['motherOfficeAddress'] as String? ?? '',
    motherContactNos: json['motherContactNos'] as String? ?? '',
    guardianName: json['guardianName'] as String? ?? '',
    guardianContactNos: json['guardianContactNos'] as String? ?? '',
    previousMartialArts: json['previousMartialArts'] as String? ?? '',
    otherHobbiesSports: json['otherHobbiesSports'] as String? ?? '',
    healthConditions: json['healthConditions'] as String? ?? '',
    photoBase64: json['photoBase64'] as String? ?? '',
  );
}
