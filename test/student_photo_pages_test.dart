import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/promotion_record.dart';
import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/screens/achievement_screen.dart';
import 'package:tkd_app/screens/promotion_screen.dart';
import 'package:tkd_app/screens/students_screen.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/promotion_storage.dart';
import 'package:tkd_app/services/student_storage.dart';
import 'package:tkd_app/widgets/student_avatar.dart';

/// A real 1 x 1 transparent PNG: the same bytes an uploaded picture is saved
/// as, so every page below draws something an image codec accepts.
final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
]);

/// What the upload form saves on the student row: plain base64.
final String _savedPhoto = base64Encode(_png);

/// Flushes the database work and the frames the screens need, the same way the
/// app own widget test does: real SQLite only answers on the real event loop,
/// so real time is yielded with [WidgetTester.runAsync] while frames are pumped
/// on the fake clock.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 80));
  }
}

/// Opens [page] the way selecting the destination does: the previous screen is
/// unmounted first, so the page starts from `initState` and reads the saved
/// rows again instead of keeping the state of an earlier visit.
Future<void> _openPage(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
  await _settle(tester);
}

/// Saves one student with a picture and one promotion record: the rows the app
/// writes when a student is added, a photo uploaded and a belt recorded. The
/// picture is saved on the student row itself, with no extra record anywhere.
Future<void> _seedStudent() async {
  final saved = await StudentStorage().insert(
    Student(name: 'Jrey Neil', nickname: 'Jrey', photoBase64: _savedPhoto),
  );
  await PromotionStorage().saveForStudent(
    PromotionRecord(
      studentId: saved.id!,
      belt: '9th Grade White',
      lastPromotionDate: '01/05/2026',
    ),
  );
}

/// The bytes of the picture the avatars on screen are drawing.
Uint8List _shownPhoto(WidgetTester tester) {
  final image = tester.widget<Image>(
    find
        .descendant(
          of: find.byType(StudentAvatar),
          matching: find.byType(Image),
        )
        .first,
  );
  return (image.image as MemoryImage).bytes;
}

/// The initials fallback of a student, when it is drawn instead of a picture.
Finder _initialsOf(String initials) => find.descendant(
  of: find.byType(StudentAvatar),
  matching: find.text(initials),
);

void main() {
  setUpAll(() {
    // The screens read and write the real database, so it is opened through
    // the FFI implementation instead of a platform channel.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.debugReset();
    AppDatabase.debugOverridePath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await AppDatabase.debugReset();
  });

  testWidgets('the Students page draws the saved picture', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(_seedStudent);
    await _openPage(tester, const StudentsScreen());

    expect(find.text('Jrey Neil'), findsOneWidget);
    expect(find.byType(StudentAvatar), findsOneWidget);
    expect(_shownPhoto(tester), _png);
    // The initials are only the fallback, so they are not drawn as well.
    expect(_initialsOf('JN'), findsNothing);
  });

  testWidgets('the Promotion page draws the same saved picture', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(_seedStudent);
    await _openPage(tester, const PromotionScreen());

    expect(find.text('Jrey Neil'), findsOneWidget);
    expect(find.byType(StudentAvatar), findsOneWidget);
    expect(_shownPhoto(tester), _png);
    expect(_initialsOf('JN'), findsNothing);
  });

  testWidgets('the Achievement page draws the same saved picture', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(_seedStudent);
    await _openPage(tester, const AchievementScreen());

    expect(find.text('Jrey Neil'), findsOneWidget);
    expect(find.byType(StudentAvatar), findsOneWidget);
    expect(_shownPhoto(tester), _png);
    expect(_initialsOf('JN'), findsNothing);
  });

  testWidgets('a change to the picture reaches every page, on one student', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(_seedStudent);

    await _openPage(tester, const StudentsScreen());
    expect(_shownPhoto(tester), _png);

    final saved = (await tester.runAsync(StudentStorage().loadStudents))!.single;

    // The edit the information sheet performs when the picture is replaced:
    // the same row is written, so the registry still holds one student.
    await tester.runAsync(
      () => StudentStorage().update(
        Student(
          id: saved.id,
          studentNo: saved.studentNo,
          name: saved.name,
          photoBase64: _savedPhoto,
        ),
      ),
    );

    // Clearing the picture is picked up on the same row, not by adding a
    // student: a row without a picture falls back to the initials.
    await tester.runAsync(
      () => StudentStorage().update(
        Student(
          id: saved.id,
          studentNo: saved.studentNo,
          name: saved.name,
        ),
      ),
    );

    await _openPage(tester, const StudentsScreen());
    expect(_initialsOf('JN'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(StudentAvatar),
        matching: find.byType(Image),
      ),
      findsNothing,
    );

    await _openPage(tester, const AchievementScreen());
    expect(_initialsOf('JN'), findsOneWidget);

    // Uploading a picture again puts it back on the card of that same student.
    await tester.runAsync(
      () => StudentStorage().update(
        Student(
          id: saved.id,
          studentNo: saved.studentNo,
          name: saved.name,
          photoBase64: _savedPhoto,
        ),
      ),
    );

    await _openPage(tester, const PromotionScreen());
    expect(_shownPhoto(tester), _png);
    expect((await tester.runAsync(StudentStorage().loadStudents))!.length, 1);
  });

  test('the picture is still there after the app is restarted', () async {
    final folder = await Directory.systemTemp.createTemp('tkd_app_photo');
    // Close the database before removing the folder: Windows keeps an open
    // file locked, and `debugReset` is what closing the app does.
    addTearDown(() async {
      await AppDatabase.debugReset();
      if (folder.existsSync()) await folder.delete(recursive: true);
    });
    final path = p.join(folder.path, 'tkd_app.db');

    // First run: the student and their picture are saved into the database
    // file.
    await AppDatabase.debugReset();
    AppDatabase.debugOverridePath = path;
    final saved = await StudentStorage().insert(
      Student(name: 'Jrey Neil', photoBase64: _savedPhoto),
    );

    // The app closes and is opened again: the file is read from scratch, which
    // is exactly what a restart looks like to the storage layer.
    await AppDatabase.debugReset();
    AppDatabase.debugOverridePath = path;

    final reloaded = (await StudentStorage().loadStudents()).single;
    expect(reloaded.id, saved.id);
    expect(reloaded.photoBase64, _savedPhoto);
    expect(reloaded.photoBytes, _png);
  });
}