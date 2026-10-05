import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/student_storage.dart';

/// A real PNG that is far over the "large photo" threshold: random pixels do
/// not compress, so 300 x 300 comes out at several hundred kilobytes.
Future<Uint8List> _largeNoisyPng() async {
  const side = 300;
  final random = Random(7);
  final pixels = Uint8List(side * side * 4);
  for (var i = 0; i < pixels.length; i++) {
    pixels[i] = random.nextInt(256);
  }
  final decoded = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    side,
    side,
    ui.PixelFormat.rgba8888,
    decoded.complete,
  );
  final image = await decoded.future;
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// The two picture columns of one student, straight from the table.
Future<Map<String, Object?>> _photoColumns(int id) async {
  final db = await AppDatabase.instance.database;
  final rows = await db.query(
    'students',
    columns: ['photo_base64', 'photo_full_base64'],
    where: 'id = ?',
    whereArgs: [id],
  );
  return rows.single;
}

void main() {
  final StudentStorage storage = StudentStorage();

  setUpAll(() {
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

  testWidgets(
    'an old full-size picture is kept as the original and gets a compact copy',
    (WidgetTester tester) async {
      await tester.runAsync(() async {
        final original = base64Encode(await _largeNoisyPng());
        // What a version before the compact copy saved: the big picture in
        // `photo_base64`, nothing in `photo_full_base64`.
        final saved = await storage.insert(
          Student(name: 'Old Photo', photoBase64: original),
        );
        final revisionBefore = StudentStorage.revision;

        expect(await storage.shrinkLargePhotos(), 1);

        final columns = await _photoColumns(saved.id!);
        final compact = columns['photo_base64'] as String;
        // The original is never lost: it moved to the second column untouched.
        expect(columns['photo_full_base64'], original);
        // The compact copy is smaller and still a picture the app can draw.
        expect(compact.length, lessThan(original.length));
        expect(Student.decodePhoto(compact), isNotNull);
        // Pages that already read the registry are told it changed.
        expect(StudentStorage.revision, greaterThan(revisionBefore));

        // Converted rows carry an original now, so a second pass finds nothing.
        expect(await storage.shrinkLargePhotos(), 0);
        expect((await _photoColumns(saved.id!))['photo_base64'], compact);
      });
    },
  );

  testWidgets('a picture the decoder rejects is left exactly as it is', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      // Big enough to qualify, but not an image any codec accepts.
      final junk = base64Encode(Uint8List(70000));
      final saved = await storage.insert(
        Student(name: 'Odd Photo', photoBase64: junk),
      );

      expect(await storage.shrinkLargePhotos(), 0);

      final columns = await _photoColumns(saved.id!);
      expect(columns['photo_base64'], junk);
      expect(columns['photo_full_base64'], '');
    });
  });
}
