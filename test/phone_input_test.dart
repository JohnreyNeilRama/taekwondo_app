import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/screens/add_student_screen.dart';
import 'package:tkd_app/widgets/phone_input.dart';

/// The information sheet is one long form. It is pumped on a tall surface so
/// every field is built and reachable, so a test never depends on how far a
/// drag happened to move the list.
const Size _tallSurface = Size(1080, 4200);

/// The text field drawn under a label of the sheet.
///
/// The fields are found by their label rather than by the hint inside them: the
/// hint leaves the tree as soon as the field holds text, and a field the edit
/// form prefilled with a saved number never shows one at all.
Finder _fieldUnder(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextField),
);

/// What the field under [label] is holding right now.
String _textOf(WidgetTester tester, String label) =>
    tester.widget<TextField>(_fieldUnder(label)).controller!.text;

/// Stands in for the Students page: opens the sheet as a route and remembers
/// what it popped, so a test can check exactly what would have been saved.
class _Host extends StatelessWidget {
  const _Host({this.initial, required this.saved});

  final Student? initial;
  final List<Student?> saved;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<Student>(
                MaterialPageRoute<Student>(
                  builder: (_) => AddStudentScreen(initial: initial),
                ),
              );
              saved.add(result);
            },
            child: const Text('open the form'),
          ),
        ),
      ),
    );
  }
}

/// Opens the sheet the way the app does — as a route — and hands back the list
/// that receives whatever the form saves.
Future<List<Student?>> _openForm(
  WidgetTester tester, {
  Student? initial,
}) async {
  tester.view.physicalSize = _tallSurface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final saved = <Student?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: _Host(initial: initial, saved: saved),
    ),
  );
  await tester.tap(find.text('open the form'));
  await tester.pumpAndSettle();
  return saved;
}

void main() {
  group('PhoneInput rules', () {
    test('counts digits only, so the hyphens never count', () {
      expect(PhoneInput.digitsOf('917-123-4567'), '9171234567');
      expect(PhoneInput.digitsOf('(917) 123 4567'), '9171234567');
      expect(PhoneInput.digitsOf(''), '');
    });

    test('lays the digits out as 917-123-4567, as far as they go', () {
      expect(PhoneInput.formatTelephone('917'), '917');
      expect(PhoneInput.formatTelephone('9171'), '917-1');
      expect(PhoneInput.formatTelephone('917123'), '917-123');
      expect(PhoneInput.formatTelephone('9171234'), '917-123-4');
      expect(PhoneInput.formatTelephone('9171234567'), '917-123-4567');
    });

    test('counts the digits of a telephone, and never the hyphens', () {
      // 10 digits written with hyphens, or with none at all: the same number.
      expect(PhoneInput.validateTelephone('917-123-4567'), isNull);
      expect(PhoneInput.validateTelephone('9171234567'), isNull);
      // Anything that is not a digit or a hyphen is refused.
      expect(PhoneInput.validateTelephone('917 123 4567'), isNotNull);
      expect(PhoneInput.validateTelephone('917-123-456a'), isNotNull);
    });

    test('accepts a cellphone of up to 11 digits and refuses a longer one', () {
      expect(PhoneInput.validateCellphone('09171234567'), isNull);
      expect(PhoneInput.validateCellphone('091712345678'), isNotNull);
    });

    test('refuses anything but digits in the cellphone', () {
      expect(PhoneInput.validateCellphone('0917-123-4567'), isNotNull);
      expect(PhoneInput.validateCellphone('0917 123 4567'), isNotNull);
      expect(PhoneInput.validateCellphone('0917abc'), isNotNull);
    });

    test('a telephone must be exactly 10 digits', () {
      expect(PhoneInput.validateTelephone('917-123-4567'), isNull);
      expect(PhoneInput.validateTelephone('917-123-456'), isNotNull);
      expect(PhoneInput.validateTelephone('917-123-4567-8'), isNotNull);
      expect(PhoneInput.validateTelephone('91712345678'), isNotNull);
    });

    test('both numbers are optional, so an empty field is accepted', () {
      expect(PhoneInput.validateCellphone(''), isNull);
      expect(PhoneInput.validateCellphone(null), isNull);
      expect(PhoneInput.validateTelephone(''), isNull);
      expect(PhoneInput.validateTelephone(null), isNull);
    });

    test('a number saved before these rules is accepted as long as it is not '
        'changed', () {
      expect(
        PhoneInput.validateCellphone('0917 123 4567', initial: '0917 123 4567'),
        isNull,
      );
      expect(
        PhoneInput.validateTelephone('02 1234 5678', initial: '02 1234 5678'),
        isNull,
      );
    });

    test('the formatter turns whatever arrives into digits and hyphens', () {
      final formatter = TelephoneInputFormatter();

      TextEditingValue type(String text) => formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );

      expect(type('9171234567').text, '917-123-4567');
      expect(type('917 123 4567').text, '917-123-4567');
      expect(type('(917) 123-4567').text, '917-123-4567');
      // Anything past the 10th digit is dropped.
      expect(type('91712345678901').text, '917-123-4567');
      expect(type('abc').text, '');
      expect(type('').text, '');
    });

    test('the formatter leaves the caret after the digit it was after', () {
      final formatter = TelephoneInputFormatter();
      final typed = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '9171',
          selection: TextSelection.collapsed(offset: 4),
        ),
        const TextEditingValue(
          text: '91712',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );

      expect(typed.text, '917-12');
      expect(typed.selection.baseOffset, 6);
    });
  });

  group('Add Student form: Cellphone No.', () {
    testWidgets('keeps numbers only and stops at 11 digits', (
      WidgetTester tester,
    ) async {
      await _openForm(tester);

      await tester.enterText(
        _fieldUnder('Cellphone No.'),
        '0917-abc-123-456789',
      );

      expect(_textOf(tester, 'Cellphone No.'), '09171234567');
    });

    testWidgets(
      'a number that arrives longer than 11 digits is refused when saving',
      (WidgetTester tester) async {
        final saved = await _openForm(tester);

        await tester.enterText(_fieldUnder('Full Name'), 'Ana Cruz');
        // The field cannot be typed past 11 digits, so a value arriving from
        // somewhere else is what the saving check is there for.
        tester
                .widget<TextField>(_fieldUnder('Cellphone No.'))
                .controller!
                .text =
            '091712345678';
        await tester.pump();

        await tester.tap(find.text('Save Student'));
        await tester.pumpAndSettle();

        expect(
          find.text('Cellphone No. can have at most 11 digits'),
          findsOneWidget,
        );
        expect(saved, isEmpty);
      },
    );
  });

  group('Add Student form: Telephone No.', () {
    testWidgets('is laid out as 917-123-4567 while typing', (
      WidgetTester tester,
    ) async {
      await _openForm(tester);

      await tester.enterText(_fieldUnder('Telephone No.'), '9171234567');
      expect(_textOf(tester, 'Telephone No.'), '917-123-4567');

      await tester.enterText(_fieldUnder('Telephone No.'), '91712');
      expect(_textOf(tester, 'Telephone No.'), '917-12');
    });

    testWidgets('a pasted number is not cut short by its hyphens', (
      WidgetTester tester,
    ) async {
      await _openForm(tester);

      await tester.enterText(_fieldUnder('Telephone No.'), '(917) 123-4567');

      expect(_textOf(tester, 'Telephone No.'), '917-123-4567');
    });

    testWidgets('a number with fewer than 10 digits cannot be saved', (
      WidgetTester tester,
    ) async {
      final saved = await _openForm(tester);

      await tester.enterText(_fieldUnder('Full Name'), 'Ana Cruz');
      await tester.enterText(_fieldUnder('Telephone No.'), '917123456');
      await tester.tap(find.text('Save Student'));
      await tester.pumpAndSettle();

      expect(
        find.text('Telephone No. must be exactly 10 digits (917-123-4567)'),
        findsOneWidget,
      );
      expect(saved, isEmpty);

      // Completing the number lets the form save, in the field format.
      await tester.enterText(_fieldUnder('Telephone No.'), '9171234567');
      await tester.tap(find.text('Save Student'));
      await tester.pumpAndSettle();

      expect(saved, hasLength(1));
      expect(saved.single!.name, 'Ana Cruz');
      expect(saved.single!.telephoneNos, '917-123-4567');
    });
  });

  group('Edit Student form', () {
    testWidgets(
      'a number saved before these rules is shown as saved and keeps saving '
      'unchanged',
      (WidgetTester tester) async {
        const stored = Student(
          id: 7,
          studentNo: 'TKD-0007',
          name: 'Old Student',
          telephoneNos: '02 1234 5678',
          cellphoneNo: '0917 123 4567',
        );
        final saved = await _openForm(tester, initial: stored);

        expect(find.text('Save Changes'), findsOneWidget);
        expect(_textOf(tester, 'Telephone No.'), '02 1234 5678');
        expect(_textOf(tester, 'Cellphone No.'), '0917 123 4567');

        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();

        expect(saved, hasLength(1));
        expect(saved.single!.telephoneNos, '02 1234 5678');
        expect(saved.single!.cellphoneNo, '0917 123 4567');
        // The record being edited keeps its id and registry number.
        expect(saved.single!.id, 7);
        expect(saved.single!.studentNo, 'TKD-0007');
      },
    );

    testWidgets('a saved telephone is shown exactly as it was saved', (
      WidgetTester tester,
    ) async {
      const stored = Student(
        id: 3,
        studentNo: 'TKD-0003',
        name: 'Old Student',
        telephoneNos: '0917123456',
      );
      final saved = await _openForm(tester, initial: stored);

      expect(_textOf(tester, 'Telephone No.'), '0917123456');

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(saved.single!.telephoneNos, '0917123456');
    });

    testWidgets(
      'a cellphone edited into something that is not digits is refused',
      (WidgetTester tester) async {
        final saved = await _openForm(
          tester,
          initial: const Student(
            id: 1,
            studentNo: 'TKD-0001',
            name: 'Ana Cruz',
            cellphoneNo: '0917 123 4567',
          ),
        );

        // What a value arriving from outside the field's formatter looks like.
        tester
                .widget<TextField>(_fieldUnder('Cellphone No.'))
                .controller!
                .text =
            '0917-123-4567';
        await tester.pump();

        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();

        expect(
          find.text('Cellphone No. must contain numbers only'),
          findsOneWidget,
        );
        expect(saved, isEmpty);
      },
    );
  });

  testWidgets(
    'the Contact Nos. of the parents and guardian are left as they are typed',
    (WidgetTester tester) async {
      final saved = await _openForm(tester);

      await tester.enterText(_fieldUnder('Full Name'), 'Ana Cruz');
      await tester.enterText(
        find.widgetWithText(TextField, "Enter Father's Contact Nos."),
        '02 8888 7777 / 0917 555 0000',
      );
      await tester.enterText(
        find.widgetWithText(TextField, "Enter Mother's Contact Nos."),
        'abc-123',
      );
      await tester.tap(find.text('Save Student'));
      await tester.pumpAndSettle();

      expect(saved, hasLength(1));
      expect(saved.single!.fatherContactNos, '02 8888 7777 / 0917 555 0000');
      expect(saved.single!.motherContactNos, 'abc-123');
    },
  );
}
