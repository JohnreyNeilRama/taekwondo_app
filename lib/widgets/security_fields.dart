import 'package:flutter/material.dart';

import '../theme/app_dark.dart';
import 'app_input.dart';

/// The input decoration every security screen uses: the same dark box as every
/// other field in the app, with a quiet border that turns crimson when focused
/// and a soft red when it holds a message.
InputDecoration securityDecoration({String? hint, Widget? suffixIcon}) =>
    AppInput.decoration(hint: hint, suffixIcon: suffixIcon);

/// A label above an input, the same as on the information sheet.
Widget securityLabel(String label) => AppInput.label(label);

/// One input of a security screen. [obscured] turns on the show/hide eye, so a
/// password can be checked as it is typed without leaving it on the screen.
class SecurityTextField extends StatefulWidget {
  const SecurityTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.obscured = false,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;

  /// Icon at the left of the field, the way the date field on the promotion
  /// form has one.
  final IconData? icon;

  /// Whether the text is hidden behind dots, with an eye to show it again.
  final bool obscured;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<SecurityTextField> createState() => _SecurityTextFieldState();
}

class _SecurityTextFieldState extends State<SecurityTextField> {
  late bool _visible;

  @override
  void initState() {
    super.initState();
    _visible = !widget.obscured;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        securityLabel(widget.label),
        TextFormField(
          controller: widget.controller,
          autofocus: widget.autofocus,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          obscureText: !_visible,
          obscuringCharacter: '•',
          autocorrect: false,
          enableSuggestions: !widget.obscured,
          cursorColor: AppDark.crimson,
          style: const TextStyle(color: AppDark.textPrimary, fontSize: 15),
          decoration: AppInput.decoration(
            hint: widget.hint,
            prefixIcon: widget.icon == null
                ? null
                : Icon(widget.icon, size: 20),
            suffixIcon: widget.obscured
                ? IconButton(
                    tooltip: _visible ? 'Hide password' : 'Show password',
                    icon: Icon(
                      _visible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: AppDark.textSecondary,
                    ),
                    onPressed: () => setState(() => _visible = !_visible),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
