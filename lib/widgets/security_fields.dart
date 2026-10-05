import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The input decoration every security screen uses, matching the other forms in
/// the app: white field, thin grey border, black when it is focused, red when
/// it holds a message, 10px corners.
InputDecoration securityDecoration({String? hint, Widget? suffixIcon}) {
  OutlineInputBorder border() => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: AppColors.border),
  );

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(),
    enabledBorder: border(),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.black, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.red),
    ),
    suffixIcon: suffixIcon,
  );
}

/// A label above an input, in the style the information sheet and the promotion
/// form already use.
Widget securityLabel(String label) => Padding(
  padding: const EdgeInsets.only(left: 2, bottom: 6),
  child: Text(
    label,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.muted,
    ),
  ),
);

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
          decoration: securityDecoration(
            hint: widget.hint,
            suffixIcon: widget.obscured
                ? IconButton(
                    tooltip: _visible ? 'Hide password' : 'Show password',
                    icon: Icon(
                      _visible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: AppColors.muted,
                    ),
                    onPressed: () => setState(() => _visible = !_visible),
                  )
                : (widget.icon == null
                      ? null
                      : Icon(widget.icon, size: 20, color: AppColors.black)),
          ),
        ),
      ],
    );
  }
}
