import 'package:flutter/material.dart';

import '../theme/app_dark.dart';

/// The search card of the Students page: a large rounded dark card with the
/// search glass, the text field, a clear button while something is typed, and
/// a sort button at the right.
///
/// Its border turns crimson while the field has focus. The card is one
/// [TextField] and nothing else, so a page that uses it still has exactly one
/// text field on it.
class StudentSearchBar extends StatefulWidget {
  const StudentSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hasQuery,
    required this.onClear,
    required this.onSort,
    this.sortActive = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// Whether the clear (x) button is shown.
  final bool hasQuery;
  final VoidCallback onClear;

  /// Opens the sort choices.
  final VoidCallback onSort;

  /// True when the list is sorted in a way other than the default, which puts a
  /// small crimson dot on the sort button.
  final bool sortActive;

  /// Height of the card.
  static const double height = 52;

  @override
  State<StudentSearchBar> createState() => _StudentSearchBarState();
}

class _StudentSearchBarState extends State<StudentSearchBar> {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // The long hint would be cut on a narrow phone, so it shortens there.
        final hint = constraints.maxWidth < 330
            ? 'Search students'
            : 'Search name, nickname, school, contact...';
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: StudentSearchBar.height,
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
          // The buttons ripple on this layer, above the card's own colour.
          child: Material(
            type: MaterialType.transparency,
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
                    cursorColor: AppDark.crimson,
                    style: const TextStyle(
                      color: AppDark.textPrimary,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: hint,
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
                  ),
                Container(width: 1, height: 24, color: AppDark.border),
                _SortButton(
                  onPressed: widget.onSort,
                  active: widget.sortActive,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The sort button at the right end of the search card, 48 px square.
class _SortButton extends StatelessWidget {
  const _SortButton({required this.onPressed, required this.active});

  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Sort',
      child: InkWell(
        onTap: onPressed,
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(16),
        ),
        child: SizedBox(
          width: 52,
          height: StudentSearchBar.height - 2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.tune_rounded, size: 22, color: AppDark.icon),
              if (active)
                Positioned(
                  top: 12,
                  right: 13,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppDark.crimson,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
