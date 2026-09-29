import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The one search field used on the Students, Achievement, and Pending
/// Students / Select Student pages.
///
/// Kept as a single widget so all three always share the exact same height,
/// border style, border width, border radius and fill colour, with the hint
/// and typed text centred both vertically and horizontally inside the box.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.hasQuery,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  /// Whether the clear (x) button should be shown.
  final bool hasQuery;
  final VoidCallback onClear;

  /// One border used for every state (enabled, focused, default) so the box
  /// never changes appearance on tap.
  static const OutlineInputBorder _border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: AppColors.black, width: 1),
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        // Centres the typed/hint text both horizontally and vertically;
        // without textAlignVertical the text also sits a little above centre
        // once a prefix icon is present.
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(fontSize: 13, color: AppColors.black),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintTextDirection: TextDirection.ltr,
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: AppColors.muted,
          ),
          // A tight, matched box for both icons so neither one forces the
          // field taller than 44 and throws off the vertical centring.
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          suffixIcon: hasQuery
              ? IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.muted,
                  ),
                  onPressed: onClear,
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          filled: true,
          fillColor: AppColors.surface,
          // More room on the right than on the left nudges the centred
          // hint/text a little to the left of the box centre, while the small
          // left padding keeps it from crowding the search glass.
          contentPadding: const EdgeInsets.fromLTRB(4, 12, 40, 12),
          border: _border,
          enabledBorder: _border,
          focusedBorder: _border,
          disabledBorder: _border,
        ),
      ),
    );
  }
}
