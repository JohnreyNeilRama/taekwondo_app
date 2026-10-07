import 'package:flutter/material.dart';

import '../theme/app_dark.dart';

/// The one search field used on the Promotion, Achievement, and Pending
/// Students / Select Student pages: a large rounded dark card with a search
/// glass, the text, and a clear button while something is typed. Its border
/// turns crimson while the field has focus.
///
/// Kept as a single widget so every page shares the same height, border,
/// corners, fill and font, and the same layout inside the box: the glass sits
/// at a fixed distance from the left border and the hint and typed text start
/// at a fixed distance from the glass, whatever the box width.
class AppSearchField extends StatefulWidget {
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
  static const double height = 52;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      height: AppSearchField.height,
      decoration: BoxDecoration(
        color: AppDark.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: focused ? AppDark.crimson : AppDark.border,
          width: focused ? 1.5 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: AppDark.crimson.withValues(alpha: 0.18),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(
            Icons.search_rounded,
            size: 22,
            color: AppDark.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              onChanged: widget.onChanged,
              textInputAction: TextInputAction.search,
              textAlignVertical: TextAlignVertical.center,
              cursorColor: AppDark.crimson,
              style: const TextStyle(color: AppDark.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.hintText,
                hintMaxLines: 1,
                hintStyle: const TextStyle(
                  color: AppDark.textSecondary,
                  fontSize: 14,
                  overflow: TextOverflow.ellipsis,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (widget.hasQuery)
            IconButton(
              tooltip: 'Clear search',
              onPressed: widget.onClear,
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
                color: AppDark.textSecondary,
              ),
            )
          else
            const SizedBox(width: 14),
        ],
      ),
    );
  }
}
