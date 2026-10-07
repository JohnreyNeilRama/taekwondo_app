import 'package:flutter/material.dart';

import 'app_dark.dart';

/// The colour names the pages were written with, now pointing at the dark
/// palette so every page draws from the same one.
///
/// `black` is the "ink" colour (primary text and icons): it is white on the
/// dark pages, which is why it must never be used as a background. Backgrounds
/// come from [AppDark] directly.
class AppColors {
  const AppColors._();

  /// Primary text and icons (white on the dark pages).
  static const Color black = AppDark.textPrimary;
  static const Color red = AppDark.crimson;

  /// A wash of the accent, for soft highlights on a surface.
  static const Color redTint = AppDark.crimsonTint;
  static const Color background = AppDark.background;
  static const Color surface = AppDark.surface;
  static const Color border = AppDark.border;
  static const Color muted = AppDark.textSecondary;
  static const Color iconCircle = AppDark.surfaceHigh;

  /// Training cancelled: neither present nor absent.
  static const Color cancelled = Color(0xFFEAB308);
  static const Color onCancelled = Color(0xFF713F12);
}

/// The one theme of the app, in the palette that is in use ([AppDark.isLight]):
/// the navy surfaces or the soft white ones, with the crimson accent, applied to
/// buttons, dialogs, sheets, menus, snack bars, pickers and the other controls,
/// so a control that no page styles by hand still matches.
///
/// It reads the palette when it is called, so it is built again when the mode
/// changes.
ThemeData buildAppTheme() {
  final brightness = AppDark.isLight ? Brightness.light : Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: AppDark.crimson,
    onPrimary: Colors.white,
    secondary: AppDark.rose,
    onSecondary: AppDark.crimsonTint,
    error: AppDark.error,
    onError: Colors.white,
    surface: AppDark.surface,
    onSurface: AppDark.textPrimary,
    onSurfaceVariant: AppDark.textSecondary,
    outline: AppDark.border,
    outlineVariant: AppDark.border,
    primaryContainer: AppDark.crimsonTint,
    onPrimaryContainer: AppDark.rose,
    secondaryContainer: AppDark.crimsonTint,
    onSecondaryContainer: AppDark.rose,
    surfaceContainerHighest: AppDark.surfaceHigh,
    surfaceContainerHigh: AppDark.surfaceHigh,
    surfaceContainer: AppDark.surface,
    surfaceContainerLow: AppDark.surface,
    surfaceContainerLowest: AppDark.background,
    surfaceTint: Colors.transparent,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
  );

  final shape14 = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppDark.background,
    canvasColor: AppDark.surface,
    textTheme: base.textTheme.apply(
      bodyColor: AppDark.textPrimary,
      displayColor: AppDark.textPrimary,
    ),
    iconTheme: const IconThemeData(color: AppDark.icon),
    dividerTheme: const DividerThemeData(
      color: AppDark.border,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppDark.crimson,
      linearTrackColor: AppDark.border,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppDark.crimson,
      selectionColor: AppDark.crimson.withValues(alpha: 0.35),
      selectionHandleColor: AppDark.crimson,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppDark.crimson,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppDark.surfaceHigh,
        disabledForegroundColor: AppDark.textSecondary,
        minimumSize: const Size(0, 48),
        shape: shape14,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppDark.textPrimary,
        disabledForegroundColor: AppDark.textSecondary,
        side: const BorderSide(color: AppDark.border),
        minimumSize: const Size(0, 48),
        shape: shape14,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppDark.rose,
        minimumSize: const Size(0, 44),
        shape: shape14,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: AppDark.icon),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppDark.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppDark.border),
      ),
      titleTextStyle: const TextStyle(
        color: AppDark.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: const TextStyle(
        color: AppDark.textSecondary,
        fontSize: 14,
        height: 1.4,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppDark.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppDark.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppDark.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppDark.surfaceHigh,
      contentTextStyle: const TextStyle(
        color: AppDark.textPrimary,
        fontSize: 14,
      ),
      actionTextColor: AppDark.rose,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppDark.border),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppDark.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppDark.border),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppDark.surfaceHigh,
      selectedColor: AppDark.crimsonTint,
      checkmarkColor: AppDark.rose,
      side: const BorderSide(color: AppDark.border),
      labelStyle: const TextStyle(
        color: AppDark.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppDark.icon,
      textColor: AppDark.textPrimary,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : AppDark.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppDark.crimson
            : AppDark.surfaceHigh,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppDark.crimson
            : AppDark.border,
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppDark.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppDark.border),
      ),
      textStyle: const TextStyle(color: AppDark.textPrimary, fontSize: 12),
    ),
  );
}
