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

  test('the contact columns save and read back both number shapes', () async {
    // What the form writes today: an 11-digit cellphone and a 10-digit
    // telephone laid out as 917-123-4567.
    final saved = await storage.insert(
      const Student(
        name: 'Ana Cruz',
        telephoneNos: '917-123-4567',
        cellphoneNo: '09171234567',
      ),
    );
    final restored = (await storage.loadStudents()).single;

    expect(restored.telephoneNos, '917-123-4567');
    expect(restored.cellphoneNo, '09171234567');

    // And what an older record holds: an edit that does not touch these two
    // fields writes them back exactly as they were saved.
    await storage.update(
      Student(
        id: saved.id,
        studentNo: saved.studentNo,
        name: 'Ana Cruz',
        telephoneNos: '02 1234 5678',
        cellphoneNo: '0917 123 4567',
      ),
    );

    final edited = (await storage.loadStudents()).single;
    expect(edited.telephoneNos, '02 1234 5678');
    expect(edited.cellphoneNo, '0917 123 4567');
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

  test(
    'permanently deleting a student closes the gap in the numbers after them',
    () async {
      final a = await storage.insert(_filled);
      final b = await storage.insert(_filled);
      final c = await storage.insert(_filled);
      final d = await storage.insert(_filled);
      expect(
        [
          for (final s in [a, b, c, d]) s.studentNo,
        ],
        ['TKD-0001', 'TKD-0002', 'TKD-0003', 'TKD-0004'],
      );

      await storage.moveToTrash(b.id!);
      await storage.deletePermanently(b.id!);

      final remaining = await storage.loadStudents();
      // c and d move up to take the numbers b left behind; a is untouched.
      expect([for (final s in remaining) s.id], [a.id, c.id, d.id]);
      expect(
        [for (final s in remaining) s.studentNo],
        ['TKD-0001', 'TKD-0002', 'TKD-0003'],
      );
    },
  );

  test(
    'a new student after a permanent delete takes the freed number',
    () async {
      final a = await storage.insert(_filled);
      await storage.insert(_filled); // b
      await storage.insert(_filled); // c
      await storage.insert(_filled); // d, TKD-0004

      await storage.moveToTrash(a.id!);
      await storage.deletePermanently(a.id!);
      // b, c, d are now TKD-0001..0003; the freed top number is 0004.

      final next = await storage.insert(_filled);
      expect(next.studentNo, 'TKD-0004');
      expect((await storage.loadStudents()).map((s) => s.studentNo), [
        'TKD-0001',
        'TKD-0002',
        'TKD-0003',
        'TKD-0004',
      ]);
    },
  );

  test('moving a student to Trash leaves every number where it is', () async {
    final a = await storage.insert(_filled);
    final b = await storage.insert(_filled);
    final c = await storage.insert(_filled);

    await storage.moveToTrash(b.id!);

    // Nobody moves up: the gap stays, because b's number is reserved.
    final active = await storage.loadStudents();
    expect([for (final s in active) s.id], [a.id, c.id]);
    expect([for (final s in active) s.studentNo], ['TKD-0001', 'TKD-0003']);

    // And b keeps the number they had.
    final trash = await storage.loadTrash();
    expect(trash.single.student.id, b.id);
    expect(trash.single.student.studentNo, 'TKD-0002');
  });

  test(
    'restoring a student never duplicates a number taken while they were away',
    () async {
      final a = await storage.insert(_filled);
      final b = await storage.insert(_filled);
      final c = await storage.insert(_filled);
      final d = await storage.insert(_filled);
      // TKD-0001..0004

      // b goes to the Trash and keeps TKD-0002 reserved; nobody moves.
      await storage.moveToTrash(b.id!);

      // a is permanently deleted while b is still away. Everyone after a moves
      // up to close the gap, b included (b keeps their place in the order):
      // b, c, d become TKD-0001..0003.
      await storage.moveToTrash(a.id!);
      await storage.deletePermanently(a.id!);

      // Restoring b gives them back the number they hold now; it is theirs, so
      // it cannot collide with anybody.
      await storage.restoreFromTrash(b.id!);

      final active = await storage.loadStudents();
      final numbers = [for (final s in active) s.studentNo];
      // Unique and sequential, whatever the exact assignment turns out to be.
      expect(numbers.toSet(), hasLength(numbers.length));
      expect(numbers..sort(), ['TKD-0001', 'TKD-0002', 'TKD-0003']);
      // b was added before c and d, so by id order it leads them again.
      expect([for (final s in active) s.id], [b.id, c.id, d.id]);
    },
  );

  test(
    'a trashed student keeps their number and a permanent delete passes it on',
    () async {
      final s1 = await storage.insert(_filled);
      final s2 = await storage.insert(_filled);
      final s3 = await storage.insert(_filled);

      // Trash: student 1 keeps TKD-0001 and nobody else moves.
      await storage.moveToTrash(s1.id!);
      var active = await storage.loadStudents();
      expect([for (final s in active) s.id], [s2.id, s3.id]);
      expect([for (final s in active) s.studentNo], ['TKD-0002', 'TKD-0003']);
      expect((await storage.loadTrash()).single.student.studentNo, 'TKD-0001');

      // Permanent delete: students 2 and 3 move up into the freed numbers.
      await storage.deletePermanently(s1.id!);
      active = await storage.loadStudents();
      expect([for (final s in active) s.id], [s2.id, s3.id]);
      expect([for (final s in active) s.studentNo], ['TKD-0001', 'TKD-0002']);

      // The next new student continues the sequence with TKD-0003.
      final next = await storage.insert(_filled);
      expect(next.studentNo, 'TKD-0003');
    },
  );

  test(
    'a new student never takes a number that is reserved in the Trash',
    () async {
      await storage.insert(_filled); // TKD-0001
      await storage.insert(_filled); // TKD-0002
      final c = await storage.insert(_filled); // TKD-0003
      await storage.moveToTrash(c.id!);

      // TKD-0003 belongs to c until they are gone for good.
      final next = await storage.insert(_filled);
      expect(next.studentNo, 'TKD-0004');

      // Once c is permanently deleted, the newcomer moves up into their place.
      await storage.deletePermanently(c.id!);
      final active = await storage.loadStudents();
      expect(
        [for (final s in active) s.studentNo],
        ['TKD-0001', 'TKD-0002', 'TKD-0003'],
      );
      expect(active.last.id, next.id);
    },
  );

  test('restoring a student gives back their original number', () async {
    final a = await storage.insert(_filled);
    final b = await storage.insert(_filled);
    final c = await storage.insert(_filled);

    await storage.moveToTrash(a.id!);
    await storage.restoreFromTrash(a.id!);

    final active = await storage.loadStudents();
    expect([for (final s in active) s.id], [a.id, b.id, c.id]);
    expect(
      [for (final s in active) s.studentNo],
      ['TKD-0001', 'TKD-0002', 'TKD-0003'],
    );
    expect(await storage.loadTrash(), isEmpty);
  });

  test(
    'a permanent delete also moves up the students waiting in the Trash',
    () async {
      final a = await storage.insert(_filled);
      final b = await storage.insert(_filled);
      final c = await storage.insert(_filled);
      final d = await storage.insert(_filled);

      await storage.moveToTrash(c.id!);
      await storage.moveToTrash(a.id!);
      await storage.deletePermanently(a.id!);

      // b and d are active; c is still in the Trash, one place after b.
      final active = await storage.loadStudents();
      expect([for (final s in active) s.id], [b.id, d.id]);
      expect([for (final s in active) s.studentNo], ['TKD-0001', 'TKD-0003']);
      expect((await storage.loadTrash()).single.student.studentNo, 'TKD-0002');

      // So c comes back into the gap that was kept for them.
      await storage.restoreFromTrash(c.id!);
      final all = await storage.loadStudents();
      expect([for (final s in all) s.id], [b.id, c.id, d.id]);
      expect(
        [for (final s in all) s.studentNo],
        ['TKD-0001', 'TKD-0002', 'TKD-0003'],
      );
    },
  );

  test(
    'editing with an out-of-date record never writes an old number back',
    () async {
      final a = await storage.insert(_filled);
      final b = await storage.insert(_filled); // TKD-0002
      await storage.moveToTrash(a.id!);
      await storage.deletePermanently(a.id!); // b moves up to TKD-0001

      // `b` still carries the TKD-0002 it had when it was read.
      await storage.update(
        Student(id: b.id, studentNo: b.studentNo, name: 'Renamed'),
      );

      final saved = (await storage.loadStudents()).single;
      expect(saved.name, 'Renamed');
      expect(saved.studentNo, 'TKD-0001');
    },
  );

  test(
    'renumberStudents packs a registry whose numbers are out of order',
    () async {
      // Every row holds somebody else's number, so each move would collide with
      // the next one if the numbers were simply rewritten one by one.
      final db = await AppDatabase.instance.database;
      for (final no in ['TKD-0003', 'TKD-0001', 'TKD-0002']) {
        await db.insert('students', {'student_no': no, 'name': 'S $no'});
      }

      await storage.renumberStudents();

      final rows = await db.query('students', orderBy: 'id');
      expect(
        [for (final r in rows) r['student_no']],
        ['TKD-0001', 'TKD-0002', 'TKD-0003'],
      );
      // The order they were added in is kept: the first row is still 'S TKD-0003'.
      expect(rows.first['name'], 'S TKD-0003');
    },
  );

  test(
    'every student is given a permanent identity that an edit never changes',
    () async {
      final saved = await storage.insert(_filled);
      expect(saved.uid, isNotEmpty);

      final db = await AppDatabase.instance.database;
      final stored = (await db.query('students', columns: ['uid'])).single;
      expect(stored['uid'], saved.uid);

      // An edit carried out with a record that has no uid (a form, for example)
      // must keep the saved identity instead of blanking it.
      await storage.update(Student(id: saved.id, name: 'Renamed'));
      final after = (await db.query('students', columns: ['uid'])).single;
      expect(after['uid'], saved.uid);
    },
  );

  test('ensureStudentUids stamps a record saved before uids existed', () async {
    // A row written straight into the table, the way an older version left it.
    final db = await AppDatabase.instance.database;
    await db.insert('students', {'student_no': 'TKD-0001', 'name': 'Old Row'});
    expect((await db.query('students', columns: ['uid'])).single['uid'], '');

    expect(await storage.ensureStudentUids(), 1);
    final uid = (await db.query('students', columns: ['uid'])).single['uid'];
    expect(uid, isNotEmpty);

    // A registry that is already stamped is left alone.
    expect(await storage.ensureStudentUids(), 0);
  });
}
