import 'package:flutter/material.dart';

/// Colour palette for the TKD Records app (black / white / red).
class AppColors {
  const AppColors._();

  static const Color black = Color(0xFF111111);
  static const Color red = Color(0xFFDC2626);
  static const Color redTint = Color(0xFFFDECEC);
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE5E5E5);
  static const Color muted = Color(0xFF6B7280);
  static const Color iconCircle = Color(0xFFEBEBEB);
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(seedColor: AppColors.red).copyWith(
    primary: AppColors.black,
    onPrimary: Colors.white,
    surface: AppColors.surface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.black,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
