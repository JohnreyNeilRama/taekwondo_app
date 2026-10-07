import 'package:flutter/material.dart';

/// A colour with a dark value and a light value, that reads whichever one the
/// app is using at the moment it is painted.
///
/// Every page names its colours through [AppDark] and writes them in `const`
/// places (`const TextStyle(color: AppDark.textPrimary)`), where a colour that
/// is looked up from a theme cannot go. A [ModeColor] is itself a constant, so
/// it fits there, and it answers with the dark or the light value depending on
/// [AppDark.isLight]. Switching the mode therefore needs no change to any page
/// but a rebuild of what is on screen, which the shell does when the switch in
/// Settings > Appearance is flipped.
class ModeColor extends Color {
  /// [value] is the dark colour, which [Color] itself keeps; [_light] is the one
  /// used in the light mode. Both are `0xAARRGGBB`.
  const ModeColor(super.value, this._light);

  final int _light;

  /// One 8-bit channel of the light colour, as the 0 to 1 number [Color] uses.
  double _lightChannel(int shift) => ((_light >> shift) & 0xFF) / 255.0;

  // In the dark mode each channel is [Color]'s own, which holds the dark value.
  @override
  double get a => AppDark.isLight ? _lightChannel(24) : super.a;

  @override
  double get r => AppDark.isLight ? _lightChannel(16) : super.r;

  @override
  double get g => AppDark.isLight ? _lightChannel(8) : super.g;

  @override
  double get b => AppDark.isLight ? _lightChannel(0) : super.b;
}

/// The palette of the app: deep navy surfaces in the dark mode, soft white
/// surfaces in the light mode, crimson as the one accent in both.
///
/// The name is kept from when the app was dark only. The header and the
/// crimson gradients are the same in both modes: the header is always the dark
/// brand bar, and the white text on the crimson buttons always reads.
class AppDark {
  const AppDark._();

  /// Whether the light palette is in use. Set by `AppearanceSettings` when the
  /// saved choice is read and when the owner flips the switch; nothing else
  /// should write it.
  static bool isLight = false;

  /// The page itself.
  static const Color background = ModeColor(0xFF0B1220, 0xFFF2F4F8);

  /// Cards and the search box: a step away from the page.
  static const Color surface = ModeColor(0xFF111B2F, 0xFFFFFFFF);

  /// Icon buttons, avatar plates and menus: a step away from a card.
  static const Color surfaceHigh = ModeColor(0xFF18243D, 0xFFECEFF5);

  /// Hairlines around cards and inputs: a quiet blue-gray.
  static const Color border = ModeColor(0xFF26324D, 0xFFDCE1EA);

  /// The bottom bar.
  static const Color navBar = ModeColor(0xFF0E1628, 0xFFFFFFFF);

  /// Top and bottom of the header's own gradient. The header is the dark brand
  /// bar in both modes. The bottom one is also what shows in the two corners the
  /// page's rounded top cuts away.
  static const Color headerTop = Color(0xFF1D1020);
  static const Color headerBottom = Color(0xFF0F1626);

  /// The accent: vivid crimson (a touch deeper on white, so it stays readable),
  /// with a deeper shade for gradients and presses.
  static const Color crimson = ModeColor(0xFFE5334B, 0xFFD62A43);
  static const Color crimsonDeep = Color(0xFFB81D35);

  /// A wash of the accent, for soft highlights and selected chips.
  static const Color crimsonTint = ModeColor(0xFF3A1824, 0xFFFDE8EC);

  /// Muted pink on dark, a deeper rose on white: the soft accent next to the
  /// crimson, used for small labels and icons.
  static const Color rose = ModeColor(0xFFF4A3B1, 0xFFC4203C);

  /// The softer red used for error text and borders.
  static const Color error = ModeColor(0xFFFF6B7F, 0xFFC81E3A);

  static const Color textPrimary = ModeColor(0xFFFFFFFF, 0xFF0F172A);

  /// Cool gray for secondary text. Reads at about 6:1 on [surface] in both
  /// modes.
  static const Color textSecondary = ModeColor(0xFF94A3B8, 0xFF5A6B82);

  /// Icons on the page's surfaces.
  static const Color icon = ModeColor(0xFFE2E8F0, 0xFF334155);

  /// The green of "present" and "backed up": bright on navy, a deep green on
  /// white so it can still be read as text there.
  static const Color success = ModeColor(0xFF4ADE80, 0xFF166534);

  /// A colour that has to be read as text or as a small icon on a card (a medal
  /// colour, say) and that was chosen for the dark pages.
  ///
  /// In the dark mode it is returned as it is. In the light mode it is darkened
  /// to the same hue at a low lightness, because gold or silver drawn on white
  /// is close to invisible. Call it where the colour is used, not once at
  /// start-up: it answers for the mode in use at that moment.
  static Color readable(Color color) {
    if (!isLight) return color;
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness <= 0.26) return color;
    return hsl.withLightness(0.26).toColor();
  }

  /// The crimson fill of the main actions: Add Student, the logo, Scan.
  static const LinearGradient crimsonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF0475E), crimsonDeep],
  );

  /// The soft drop shadow under a card: deep on navy, barely there on white.
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isLight ? 0.07 : 0.28),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  /// The red glow under a crimson button.
  static List<BoxShadow> get crimsonGlow => [
    BoxShadow(
      color: crimson.withValues(alpha: isLight ? 0.28 : 0.38),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}
