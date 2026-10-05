import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/widgets/student_avatar.dart';

/// A real 1 x 1 transparent PNG, so the avatar is handed the same kind of bytes
/// an uploaded picture produces instead of something no image codec takes.
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

/// What the upload form saves: those bytes as plain base64.
final String _savedPhoto = base64Encode(_png);

/// Builds the avatar the way the lists do, so the assertions below are about
/// the widget the app really uses.
Widget _host(Student? student, {double size = 56}) => MaterialApp(
  home: Scaffold(
    body: Center(child: StudentAvatar(student: student, size: size)),
  ),
);

/// The bytes of the picture the avatar on screen is drawing.
///
/// The avatar decodes at the size it is drawn at, so the provider is a
/// [ResizeImage] wrapped around the [MemoryImage] that holds the bytes.
Uint8List _drawnPhoto(WidgetTester tester) {
  final provider = tester.widget<Image>(find.byType(Image)).image;
  final inner = provider is ResizeImage ? provider.imageProvider : provider;
  return (inner as MemoryImage).bytes;
}

void main() {
  group('Student.decodePhoto', () {
    test('reads the plain base64 the upload form saves', () {
      expect(Student.decodePhoto(_savedPhoto), _png);
    });

    test('reads a row saved with a data URI prefix', () {
      expect(Student.decodePhoto('data:image/png;base64,$_savedPhoto'), _png);
    });

    test('answers null when there is no picture to draw', () {
      expect(Student.decodePhoto(''), isNull);
      expect(Student.decodePhoto('data:image/png;base64,'), isNull);
      expect(Student.decodePhoto('not base64!'), isNull);
    });

    test('a student without a picture has no bytes', () {
      expect(const Student(name: 'Jrey').photoBytes, isNull);
    });
  });

  group('StudentAvatar', () {
    testWidgets('draws the saved picture instead of the initials', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(Student(name: 'Jrey Neil', photoBase64: _savedPhoto)),
      );

      expect(_drawnPhoto(tester), _png);
      // The initials are only the fallback, so they are not drawn as well.
      expect(find.text('JN'), findsNothing);
    });

    testWidgets('keeps the box size of the avatar it replaces', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(Student(name: 'Jrey', photoBase64: _savedPhoto)),
      );

      expect(tester.getSize(find.byType(StudentAvatar)), const Size(56, 56));
    });

    testWidgets('a student without a picture keeps the initials', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(const Student(name: 'Jrey')));

      expect(find.byType(Image), findsNothing);
      expect(find.text('J'), findsOneWidget);
    });

    testWidgets('a corrupt saved picture falls back to the initials', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const Student(name: 'Jrey', photoBase64: 'not base64!')),
      );

      expect(find.byType(Image), findsNothing);
      expect(find.text('J'), findsOneWidget);
    });

    testWidgets('no student selected yet draws the question mark', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(null));

      expect(find.byType(Image), findsNothing);
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('one student picture is never lent to another', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StudentAvatar(
                  student: Student(name: 'Jrey Neil', photoBase64: _savedPhoto),
                  size: 56,
                ),
                const StudentAvatar(student: Student(name: 'Ann Cruz'), size: 56),
              ],
            ),
          ),
        ),
      );

      // Exactly the student who has a picture draws one; the other keeps the
      // initials of their own name.
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('AC'), findsOneWidget);
      expect(find.text('JN'), findsNothing);
    });
  });
}