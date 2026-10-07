import 'package:flutter/material.dart';

import '../theme/app_dark.dart';

/// The one look of every text field, dropdown and picker row in the app: a dark
/// card-coloured box with a quiet blue-gray border that turns crimson on focus,
/// and a soft red when it holds a message.
class AppInput {
  const AppInput._();

  /// The softer red used for error text and borders, readable on both the dark
  /// and the light pages.
  static const Color error = AppDark.error;

  static OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  /// The decoration for a [TextField] or [TextFormField].
  static InputDecoration decoration({
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppDark.textSecondary, fontSize: 14),
      filled: true,
      fillColor: AppDark.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      prefixIconColor: AppDark.textSecondary,
      suffixIconColor: AppDark.textSecondary,
      errorStyle: const TextStyle(color: error, fontSize: 12),
      border: _border(AppDark.border),
      enabledBorder: _border(AppDark.border),
      disabledBorder: _border(AppDark.border),
      focusedBorder: _border(AppDark.crimson, 1.5),
      errorBorder: _border(error),
      focusedErrorBorder: _border(error, 1.5),
    );
  }

  /// The box decoration of a row that is not a text field but should look like
  /// one (a dropdown, a date row, a student picker row).
  static BoxDecoration box() => BoxDecoration(
    color: AppDark.surface,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppDark.border),
  );

  /// The label above a field.
  static Widget label(String text, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppDark.textSecondary,
            ),
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppDark.crimson,
            ),
          ),
      ],
    ),
  );
}
