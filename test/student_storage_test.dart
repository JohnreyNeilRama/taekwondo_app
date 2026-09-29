import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/student_storage.dart';

/// One student with every field of the Taekwondo Information Sheet filled in,
/// so a test can read each one back and compare it with what was saved.
const Student _filled = Student(
  name: 'Nguyen Van A',
  nickname: 'Van A',
  homeAddress: '12 Taekwondo Street',
  telephoneNos: '02 1234 5678',
  cellphoneNo: '0917 123 4567',
  email: 'van.a@example.com',
  birthDate: '03/10/2009',
  religion: 'Roman Catholic',
  sex: 'Male',
  status: 'Student',
  schoolName: 'Rizal High School',
  gradeYearCourse: 'Grade 9 / 2nd Year / STEM',
  companyNameAddress: 'Rama Builders, 5 Mabini Street',
  fatherName: 'Nguyen Van B',
  fatherOccupation: 'Engineer',
  fatherOfficeAddress: '8 Mabini Street',
  fatherContactNos: '0917 000 1111',
  motherName: 'Tran Thi B',
  motherOccupation: 'Teacher',
  motherOfficeAddress: '9 Rizal Street',
  motherContactNos: '0917 222 3333',
  guardianName: 'Le Van C',
  guardianContactNos: '0917 444 5555',
  previousMartialArts: 'Karate, 2 years',
  otherHobbiesSports: 'Basketball',
  healthConditions: 'Mild asthma',
  photoBase64: 'data:image/jpeg;base64,QUJD',
);

/// Every stored sheet field of [student], named as it is written to the row.
/// Comparing two of these maps compares all 28 fields at once, so a missed
/// column cannot slip through.
Map<String, Object?> _snapshot(Student student) => {
  'student_no': student.studentNo,
  'name': student.name,
  'nickname': student.nickname,
  'home_address': student.homeAddress,
  'telephone_nos': student.telephoneNos,
  'cellphone_no': student.cellphoneNo,
  'email': student.email,
  'birth_date': student.birthDate,
  'religion': student.religion,
  'sex': student.sex,
  'status': student.status,
  'school_name': student.schoolName,
  'grade_year_course': student.gradeYearCourse,
  'company_name_address': student.companyNameAddress,
  'father_name': student.fatherName,
  'father_occupation': student.fatherOccupation,
  'father_office_address': student.fatherOfficeAddress,
  'father_contact_nos': student.fatherContactNos,
  'mother_name': student.motherName,
  'mother_occupation': student.motherOccupation,
  'mother_office_address': student.motherOfficeAddress,
  'mother_contact_nos': student.motherContactNos,
  'guardian_name': student.guardianName,
  'guardian_contact_nos': student.guardianContactNos,
  'previous_martial_arts': student.previousMartialArts,
  'other_hobbies_sports': student.otherHobbiesSports,
  'health_conditions': student.healthConditions,
  'photo_base64': student.photoBase64,
};

void main() {
  final StudentStorage storage = StudentStorage();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Every test starts from its own empty in-memory database, so the registry
    // on the device is never read or written.
    await AppDatabase.debugReset();
    AppDatabase.debugOverridePath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await AppDatabase.debugReset();
  });

  test('a new student is stamped with the next registry number', () async {
    final first = await storage.insert(_filled);
    final second = await storage.insert(_filled);

    expect(first.id, isNotNull);
    expect(first.studentNo, 'TKD-0001');
    expect(second.studentNo, 'TKD-0002');
    expect(second.id, isNot(first.id));

    final saved = await storage.loadStudents();
    expect([for (final student in saved) student.id], [first.id, second.id]);
    expect(
      [for (final student in saved) student.studentNo],
      ['TKD-0001', 'TKD-0002'],
    );
  });

  test('a student with all 28 fields set round-trips unchanged', () async {
    // Every field carries a value so the comparison below cannot pass just
    // because both sides are empty. The registry number is the one exception:
    // the storage layer mints it on insert.
    for (final entry in _snapshot(_filled).entries) {
      if (entry.key == 'student_no') continue;
      expect(entry.value, isNotEmpty, reason: '${entry.key} should be set');
    }

    final saved = await storage.insert(_filled);
    final restored = (await storage.loadStudents()).single;

    expect(_snapshot(saved), hasLength(28));
    // Every stored field is unchanged, and the only addition is the registry
    // number the storage layer minted.
    expect(_snapshot(restored), _snapshot(saved));
    expect(_snapshot(restored), _snapshot(_filled.withStudentNo('TKD-0001')));
    expect(restored.id, saved.id);
    expect(restored.studentNo, 'TKD-0001');
    // The photo is read back with the row: an edit must never save a record
    // without it and wipe the picture.
    expect(restored.photoBase64, 'data:image/jpeg;base64,QUJD');
  });

  test('update writes every field of the row', () async {
    final saved = await storage.insert(_filled);
    final changed = Student(
      id: saved.id,
      studentNo: saved.studentNo,
      name: 'Nguyen Van Z',
      nickname: 'Zed',
      homeAddress: '1 New Street',
      telephoneNos: '02 9999 0000',
      cellphoneNo: '0999 000 0000',
      email: 'zed@example.com',
      birthDate: '12/25/2010',
      religion: 'Buddhist',
      sex: 'Female',
      status: 'Working',
      schoolName: 'New School',
      gradeYearCourse: 'Grade 10 / STEM',
      companyNameAddress: 'New Company',
      fatherName: 'New Father',
      fatherOccupation: 'Driver',
      fatherOfficeAddress: 'New Father Office',
      fatherContactNos: '0999 111 1111',
      motherName: 'New Mother',
      motherOccupation: 'Nurse',
      motherOfficeAddress: 'New Mother Office',
      motherContactNos: '0999 222 2222',
      guardianName: 'New Guardian',
      guardianContactNos: '0999 333 3333',
      previousMartialArts: 'Judo',
      otherHobbiesSports: 'Swimming',
      healthConditions: 'None',
      photoBase64: 'data:image/png;base64,WFla',
    );

    await storage.update(changed);
    final reloaded = (await storage.loadStudents()).single;

    expect(_snapshot(reloaded), _snapshot(changed));
    expect(reloaded.id, saved.id);
    // The registry number is what the promotion and achievement records are
    // linked by, so an edit must never renumber the student.
    expect(reloaded.studentNo, 'TKD-0001');
    // One edit still means one student.
    expect(await storage.loadStudents(), hasLength(1));
  });

  test('delete removes the row', () async {
    final saved = await storage.insert(_filled);
    final deleted = await storage.delete(saved.id!);

    expect(deleted.name, 'Nguyen Van A');
    expect(await storage.loadStudents(), isEmpty);
  });

  test('a duplicate registry number is rejected', () async {
    await storage.insert(_filled.withStudentNo('TKD-0001'));

    // The same registry number twice would be two rows for one person, which
    // the UNIQUE column refuses.
    expect(
      () => storage.insert(_filled.withStudentNo('TKD-0001')),
      throwsA(isA<DatabaseException>()),
    );
    expect(await storage.loadStudents(), hasLength(1));
  });

  test('update refuses a record that was never saved', () async {
    expect(() => storage.update(_filled), throwsA(isA<ArgumentError>()));
  });

  test('delete refuses a student that is no longer saved', () async {
    expect(() => storage.delete(404), throwsA(isA<StateError>()));
  });
}
