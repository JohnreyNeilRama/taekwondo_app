import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../theme/app_dark.dart';
import 'app_database.dart';

/// How large the text of the whole app is drawn, on top of the text size the
/// phone itself is set to.
enum AppTextSize {
  small('Small', 0.9),
  standard('Default', 1.0),
  large('Large', 1.15),
  extraLarge('Extra large', 1.3);

  const AppTextSize(this.label, this.factor);

  /// The name shown in Settings.
  final String label;

  /// What the text is multiplied by: 1 leaves it as the phone has it.
  final double factor;
}

/// The display preferences of this device, kept in `app_meta` next to the other
/// small settings.
///
/// They belong to the device, not to the registry: a backup does not carry them,
/// and importing one never changes them.
class AppearanceSettings {
  /// Key the text size is kept under in `app_meta`.
  static const String textSizeKey = 'ui.text_size';

  /// Key the colour mode is kept under in `app_meta`: `light` or `dark`.
  static const String colorModeKey = 'ui.color_mode';

  /// The text size in use right now. The app listens to it, so changing it
  /// redraws every page at once, and it is what [load] and [saveTextSize] keep
  /// up to date.
  static final ValueNotifier<AppTextSize> textSize = ValueNotifier(
    AppTextSize.standard,
  );

  /// Whether the light mode is in use right now. The app listens to it and
  /// builds its pages again in the other palette when it changes. [load] and
  /// [saveLightMode] keep it, and [AppDark.isLight], up to date.
  static final ValueNotifier<bool> lightMode = ValueNotifier(false);

  /// The size saved as [text], or the default when [text] is missing or is not
  /// one of the sizes, so a damaged value can never break the app.
  static AppTextSize parse(String? text) {
    for (final size in AppTextSize.values) {
      if (size.name == text) return size;
    }
    return AppTextSize.standard;
  }

  /// Whether [text] is the saved light mode. Anything else, including a missing
  /// or damaged value, is the dark mode the app has always opened in.
  static bool parseLightMode(String? text) => text == 'light';

  /// Makes the light or dark palette the one in use. The palette is changed
  /// first, so everything that is built because the notifier fired already
  /// reads the new colours.
  static void _apply(bool light) {
    AppDark.isLight = light;
    lightMode.value = light;
  }

  /// Reads the saved text size and colour mode and makes them the ones in use.
  Future<void> load() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      AppDatabase.metaTable,
      columns: ['key', 'value'],
      where: 'key IN (?, ?)',
      whereArgs: [textSizeKey, colorModeKey],
    );
    String? sizeText;
    String? modeText;
    for (final row in rows) {
      final key = row['key'] as String?;
      final value = row['value'] as String?;
      if (key == textSizeKey) sizeText = value;
      if (key == colorModeKey) modeText = value;
    }
    textSize.value = parse(sizeText);
    _apply(parseLightMode(modeText));
  }

  /// Makes [size] the one in use and saves it. The page is redrawn at once; when
  /// saving fails the error is thrown, and the size lasts until the app closes.
  Future<void> saveTextSize(AppTextSize size) async {
    textSize.value = size;
    final db = await AppDatabase.instance.database;
    await db.insert(AppDatabase.metaTable, {
      'key': textSizeKey,
      'value': size.name,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Makes the light mode ([light] true) or the dark mode the one in use and
  /// saves it. The app is redrawn at once; when saving fails the error is
  /// thrown, and the mode lasts until the app closes.
  Future<void> saveLightMode(bool light) async {
    _apply(light);
    final db = await AppDatabase.instance.database;
    await db.insert(AppDatabase.metaTable, {
      'key': colorModeKey,
      'value': light ? 'light' : 'dark',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
