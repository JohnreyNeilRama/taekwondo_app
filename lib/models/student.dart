/// Student record built from the Taekwondo Information Sheet.
class Student {
  const Student({
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

  final String name;

  /// Registry number shown on the list card, e.g. `TKD-0001`. Assigned
  /// by the students list when a record is created; kept on edit.
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

  String get initials {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Copy of this record with a different [studentNo] (used to stamp
  /// registry numbers onto freshly created students).
  Student withStudentNo(String studentNo) => Student(
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

  /// Serializes the record so it can be persisted as JSON (see
  /// [StudentStorage]).
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
