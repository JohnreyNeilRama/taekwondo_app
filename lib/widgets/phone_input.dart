import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Input rules for the contact numbers on the Add / Edit Student form.
///
/// Only the form uses them. The `students` columns are plain text, so the rules
/// live here and the database is not involved.
///
/// Nothing here rewrites a saved number. A value stored before these rules — a
/// landline written `02 1234 5678`, say, which also happens to be 10 digits — is
/// shown exactly as it was saved and is accepted unchanged, so opening an old
/// record to change something else can never mangle it.
class PhoneInput {
  const PhoneInput._();

  /// Longest cellphone number accepted, in digits.
  static const int cellphoneMaxDigits = 11;

  /// A telephone number is exactly this many digits: a 3-digit provider / area
  /// code followed by a 7-digit subscriber number.
  static const int telephoneDigits = 10;

  /// Keeps only digits and stops at 11 of them, so nothing else can be typed or
  /// pasted into the Cellphone No. field.
  static List<TextInputFormatter> cellphoneFormatters() => [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(cellphoneMaxDigits),
  ];

  /// Formats the Telephone No. field as `917-123-4567` while the user types.
  static List<TextInputFormatter> telephoneFormatters() => [
    TelephoneInputFormatter(),
  ];

  /// [value] without anything that is not a digit; the hyphens of the telephone
  /// format are formatting only and never counted.
  static String digitsOf(String value) => value.replaceAll(RegExp(r'\D'), '');

  /// [digits] laid out as `917-123-4567`, as far as they go.
  static String formatTelephone(String digits) {
    if (digits.length <= 3) return digits;
    if (digits.length <= 6) {
      return '${digits.substring(0, 3)}-${digits.substring(3)}';
    }
    return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-'
        '${digits.substring(6)}';
  }

  /// Validates the Cellphone No. field. [initial] is the value the record was
  /// opened with: a number saved before this rule that the user did not touch
  /// keeps saving as it is.
  static String? validateCellphone(String? value, {String initial = ''}) {
    final text = (value ?? '').trim();
    if (text.isEmpty || text == initial.trim()) return null;
    if (!RegExp(r'^\d+$').hasMatch(text)) {
      return 'Cellphone No. must contain numbers only';
    }
    if (text.length > cellphoneMaxDigits) {
      return 'Cellphone No. can have at most $cellphoneMaxDigits digits';
    }
    return null;
  }

  /// Validates the Telephone No. field: empty (it is optional) or exactly 10
  /// digits — a 3-digit provider / area code and a 7-digit subscriber number.
  ///
  /// Only the digits are counted: the hyphens of the `917-123-4567` layout are
  /// formatting characters, so `917-123-4567` and `9171234567` are the same
  /// number. A field the user did not touch keeps whatever was saved, exactly
  /// as in [validateCellphone].
  static String? validateTelephone(String? value, {String initial = ''}) {
    final text = (value ?? '').trim();
    if (text.isEmpty || text == initial.trim()) return null;
    if (digitsOf(text).length != telephoneDigits ||
        !RegExp(r'^[\d-]+$').hasMatch(text)) {
      return 'Telephone No. must be exactly 10 digits (917-123-4567)';
    }
    return null;
  }
}

/// Turns whatever is typed or pasted into `917-123-4567`: digits only, at most
/// 10 of them, with the hyphens added after the 3rd and 6th digit.
class TelephoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    final cursor = newValue.selection.baseOffset < 0
        ? raw.length
        : math.min(newValue.selection.baseOffset, raw.length);

    var digits = PhoneInput.digitsOf(raw);
    if (digits.length > PhoneInput.telephoneDigits) {
      digits = digits.substring(0, PhoneInput.telephoneDigits);
    }

    // Keep the caret after the same digit it was after, wherever the hyphens
    // end up.
    final digitsBeforeCursor = math.min(
      PhoneInput.digitsOf(raw.substring(0, cursor)).length,
      digits.length,
    );
    final offset = digitsBeforeCursor <= 3
        ? digitsBeforeCursor
        : digitsBeforeCursor <= 6
        ? digitsBeforeCursor + 1
        : digitsBeforeCursor + 2;

    final formatted = PhoneInput.formatTelephone(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: math.min(offset, formatted.length),
      ),
    );
  }
}
