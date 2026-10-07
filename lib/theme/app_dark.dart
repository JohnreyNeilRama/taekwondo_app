import 'package:flutter/material.dart';

/// The dark "night" palette: deep navy surfaces, crimson as the one accent.
///
/// Kept apart from [AppColors] (the light black / white / red palette the other
/// pages still use) so a page moves to the dark look by choice, one page at a
/// time, and nothing that has not been redesigned changes by accident.
class AppDark {
  const AppDark._();

  /// The page itself.
  static const Color background = Color(0xFF0B1220);

  /// Cards and the search box: a step lighter than the page.
  static const Color surface = Color(0xFF111B2F);

  /// Icon buttons, avatar plates and menus: a step lighter than a card.
  static const Color surfaceHigh = Color(0xFF18243D);

  /// Hairlines around cards and inputs: a quiet blue-gray.
  static const Color border = Color(0xFF26324D);

  /// The bottom bar.
  static const Color navBar = Color(0xFF0E1628);

  /// Top and bottom of the header's own gradient. The bottom one is also what
  /// shows in the two corners the page's rounded top cuts away.
  static const Color headerTop = Color(0xFF1D1020);
  static const Color headerBottom = Color(0xFF0F1626);

  /// The accent: vivid crimson, with a deeper shade for gradients and presses.
  static const Color crimson = Color(0xFFE5334B);
  static const Color crimsonDeep = Color(0xFFB81D35);

  /// Muted pink, for soft accents next to the crimson.
  static const Color rose = Color(0xFFF4A3B1);

  static const Color textPrimary = Colors.white;

  /// Cool gray for secondary text. Reads at about 6:1 on [surface].
  static const Color textSecondary = Color(0xFF94A3B8);

  /// Icons on dark surfaces.
  static const Color icon = Color(0xFFE2E8F0);

  /// The crimson fill of the main actions: Add Student, the logo, Scan.
  static const LinearGradient crimsonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF0475E), crimsonDeep],
  );

  /// The soft drop shadow under a card.
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.28),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  /// The red glow under a crimson button.
  static List<BoxShadow> get crimsonGlow => [
    BoxShadow(
      color: crimson.withValues(alpha: 0.38),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}
