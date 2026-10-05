import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The one search field used on the Students, Promotion, Achievement, and
/// Pending Students / Select Student pages.
///
/// Kept as a single widget so every page always shares the exact same height,
/// border style, border width, border radius, fill colour and font, and the
/// same layout inside the box: the search glass sits at a fixed distance from
/// the left border, and the hint and typed text start at a fixed distance from
/// the glass, left aligned, whatever the box width or the hint length.
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

  /// Height of the box, the same on every page.
  static const double height = 44;

  /// Width of the box that holds the search glass. The glass is 20 wide and
  /// centred in it, so it sits 12 from the left border, and the hint / typed
  /// text starts 12 after the glass.
  static const double _iconBoxWidth = 44;

  /// One border used for every state (enabled, focused, default) so the box
  /// never changes appearance on tap.
  static const OutlineInputBorder _border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: AppColors.black, width: 1),
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        // Hint and typed text start at the left, next to the search glass.
        // `textAlignVertical` keeps them vertically centred in the box.
        textAlign: TextAlign.start,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(fontSize: 13, color: AppColors.black),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintTextDirection: TextDirection.ltr,
          // One line in every box: a long hint (the Students one) is cut with
          // an ellipsis instead of wrapping to two lines, which would sit
          // off-centre in the 44 high box and make the boxes look different.
          hintMaxLines: 1,
          hintStyle: const TextStyle(
            fontSize: 13,
            color: AppColors.muted,
            overflow: TextOverflow.ellipsis,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: AppColors.muted,
          ),
          // The text starts where this box ends, so its width sets the gap
          // between the glass and the placeholder (12). Its height is a tight,
          // matched box so neither icon forces the field taller than 44 and
          // throws off the vertical centring.
          prefixIconConstraints: const BoxConstraints(
            minWidth: _iconBoxWidth,
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
          // No left padding: the search glass box already provides it. The
          // right padding keeps long text off the border when there is no
          // clear button.
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
          border: _border,
          enabledBorder: _border,
          focusedBorder: _border,
          disabledBorder: _border,
        ),
      ),
    );
  }
}
