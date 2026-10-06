import 'dart:convert';
import 'dart:typed_data';

/// Student record built from the Taekwondo Information Sheet.
class Student {
  const Student({
    this.id,
    this.uid = '',
    this.createdAt = '',
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
    this.photoFullBase64 = '',
    this.clearPhoto = false,
  });

  /// Primary key of the `students` row. Null on a record that has not been
  /// saved yet; filled in by [StudentStorage.insert] and carried through every
  /// edit, so saving a change updates that row instead of adding a new one.
  final int? id;

  /// A random, permanent identity for this student, minted once when the
  /// record is created and never changed afterwards (see `StudentUid`).
  ///
  /// It is what lets a backup be imported onto another device (or imported
  /// again here) without adding a second copy of a student after a rename or a
  /// renumbering. An empty value means "not stamped yet"; the storage layer
  /// fills it in on the next save and on app start.
  final String uid;

  /// When this student was enrolled, as the local-time ISO 8601 text stored in
  /// the `created_at` column (e.g. `2026-10-06T09:30:00.000`).
  ///
  /// The storage layer stamps it once, when the record is created, and an edit
  /// never changes it. It is what the attendance reports use as the first day
  /// a student can be absent. An empty value means "not stamped yet" (a record
  /// that has not been saved).
  final String createdAt;

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

  /// The picture every list, header, avatar and preview draws, encoded as
  /// base64 and kept small by [PhotoProcessor] before it is saved. Keeping the
  /// compact copy on the student row is what associates one picture with the
  /// correct account on every page at once.
  final String photoBase64;

  /// The original picture the picker produced, at the size it was uploaded.
  ///
  /// It is stored beside the compact copy so the full-quality photo is never
  /// thrown away, but no screen reads it: the lists select every column except
  /// this one, which is what keeps a long registry cheap to open. Only the
  /// backup file and the "shrink saved pictures" action look at it.
  final String photoFullBase64;

  /// A one-time instruction for [StudentStorage.update]: remove the saved
  /// picture (both copies) on purpose.
  ///
  /// An empty [photoBase64] alone never removes anything, because it also
  /// means "this record does not carry the picture" (a list row, or a form that
  /// never loaded it). Only the form's explicit "Remove photo" action sets this,
  /// and it is not stored: the copies made by [withId] and [withStudentNo] drop
  /// it, so a later edit cannot remove a picture by accident.
  final bool clearPhoto;

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
    uid: uid,
    createdAt: createdAt,
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
    photoFullBase64: photoFullBase64,
  );

  /// Copy of this record carrying the enrolment time the storage layer
  /// stamped on it. Set once while a record is being created.
  Student withCreatedAt(String createdAt) => Student(
    id: id,
    uid: uid,
    createdAt: createdAt,
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
    photoFullBase64: photoFullBase64,
  );

  /// Copy of this record carrying the id the database assigned to it.
  Student withId(int id) => Student(
    id: id,
    uid: uid,
    createdAt: createdAt,
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
    photoFullBase64: photoFullBase64,
  );

  /// The row this record becomes in the `students` table. Every one of the 29
  /// sheet columns is written, so an edit can never blank a field out by
  /// leaving it out of the map.
  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'uid': uid,
    'created_at': createdAt,
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
    'photo_full_base64': photoFullBase64,
  };

  /// Rebuilds a [Student] from one `students` row. Missing or null values fall
  /// back to empty strings, so a partially filled row can never crash the app.
  factory Student.fromMap(Map<String, Object?> map) => Student(
    id: map['id'] as int?,
    uid: _text(map['uid']),
    createdAt: _text(map['created_at']),
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
    photoFullBase64: _text(map['photo_full_base64']),
  );

  /// Reads one text column, tolerating null.
  static String _text(Object? value) => value as String? ?? '';

  /// The JSON shape the versions before the database wrote to
  /// `students_v1.json`. Only the one-time import reads it; the database never
  /// uses it.
  Map<String, dynamic> toJson() => {
    'uid': uid,
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
    'photoFullBase64': photoFullBase64,
  };

  /// Copy of this record carrying the [uid] the storage layer minted for it.
  /// The identity is set once and never edited, so this is only used while a
  /// record is being created.
  Student withUid(String uid) => Student(
    id: id,
    uid: uid,
    createdAt: createdAt,
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
    photoFullBase64: photoFullBase64,
  );

  /// Rebuilds a [Student] from JSON previously written by [toJson].
  /// Missing or corrupt values fall back to empty strings so a bad
  /// record can never crash the app on startup.
  factory Student.fromJson(Map<String, dynamic> json) => Student(
    uid: json['uid'] as String? ?? '',
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
    photoFullBase64: json['photoFullBase64'] as String? ?? '',
  );
}
