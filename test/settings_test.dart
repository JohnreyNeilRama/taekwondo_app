import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/screens/appearance_screen.dart';
import 'package:tkd_app/screens/settings_screen.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/appearance_settings.dart';
import 'package:tkd_app/services/backup_service.dart';
import 'package:tkd_app/services/student_storage.dart';
import 'package:tkd_app/theme/app_dark.dart';

/// Flushes the database work and the frames the page needs: real SQLite only
/// answers on the real event loop, so real time is yielded with
/// [WidgetTester.runAsync] while frames are pumped on the fake clock.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 80));
  }
}

/// Puts the colour mode back to the dark one the app opens in. It is state
/// shared by every test in this process, so a test that turns the light mode on
/// must never leave it on for the next one.
void _resetMode() {
  AppDark.isLight = false;
  AppearanceSettings.lightMode.value = false;
}

/// The WCAG contrast ratio of two colours: 1 is none, 21 is black on white.
double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Opens the Appearance page on its own.
Future<void> _openAppearance(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(const MaterialApp(home: AppearanceScreen()));
  await _settle(tester);
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Opens the Settings page on its own, reading the rows already saved on the
/// real database.
Future<void> _openSettings(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: SettingsScreen())),
  );
  await _settle(tester);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.debugReset();
    AppDatabase.debugOverridePath = inMemoryDatabasePath;
    _resetMode();
    AppearanceSettings.textSize.value = AppTextSize.standard;
  });

  tearDown(() async {
    _resetMode();
    AppearanceSettings.textSize.value = AppTextSize.standard;
    await AppDatabase.debugReset();
  });

  group('the saved text size', () {
    test('is the default until one is chosen, and a damaged value is ignored',
        () async {
      await AppearanceSettings().load();
      expect(AppearanceSettings.textSize.value, AppTextSize.standard);

      expect(AppearanceSettings.parse(null), AppTextSize.standard);
      expect(AppearanceSettings.parse('huge'), AppTextSize.standard);
      expect(AppearanceSettings.parse('large'), AppTextSize.large);
    });

    test('is kept on the device and comes back on the next start', () async {
      await AppearanceSettings().saveTextSize(AppTextSize.large);
      expect(AppearanceSettings.textSize.value, AppTextSize.large);

      // A new start: the size in use is forgotten and read from the database.
      AppearanceSettings.textSize.value = AppTextSize.standard;
      await AppearanceSettings().load();
      expect(AppearanceSettings.textSize.value, AppTextSize.large);
    });

    test('is not carried by a backup', () async {
      await StudentStorage().insert(const Student(name: 'Ana Cruz'));
      await AppearanceSettings().saveTextSize(AppTextSize.extraLarge);

      final text = String.fromCharCodes(await BackupService().exportBytes());

      expect(text.contains(AppearanceSettings.textSizeKey), isFalse);
      expect(text.contains('extraLarge'), isFalse);
    });
  });

  group('the light mode', () {
    test('is dark until one is chosen, and a damaged value is ignored',
        () async {
      await AppearanceSettings().load();
      expect(AppearanceSettings.lightMode.value, isFalse);
      expect(AppDark.isLight, isFalse);

      expect(AppearanceSettings.parseLightMode(null), isFalse);
      expect(AppearanceSettings.parseLightMode(''), isFalse);
      expect(AppearanceSettings.parseLightMode('dark'), isFalse);
      expect(AppearanceSettings.parseLightMode('Light'), isFalse);
      expect(AppearanceSettings.parseLightMode('light'), isTrue);

      // A damaged value in the database leaves the app dark.
      final db = await AppDatabase.instance.database;
      await db.insert(AppDatabase.metaTable, {
        'key': AppearanceSettings.colorModeKey,
        'value': 'purple',
      });
      await AppearanceSettings().load();
      expect(AppearanceSettings.lightMode.value, isFalse);
      expect(AppDark.isLight, isFalse);
    });

    test('is kept on the device and comes back on the next start', () async {
      await AppearanceSettings().saveLightMode(true);
      expect(AppearanceSettings.lightMode.value, isTrue);
      expect(AppDark.isLight, isTrue);

      final db = await AppDatabase.instance.database;
      var rows = await db.query(
        AppDatabase.metaTable,
        where: 'key = ?',
        whereArgs: [AppearanceSettings.colorModeKey],
      );
      expect(rows.single['value'], 'light');

      // A new start: the mode in use is forgotten and read from the database.
      _resetMode();
      expect(AppDark.isLight, isFalse);
      await AppearanceSettings().load();
      expect(AppearanceSettings.lightMode.value, isTrue);
      expect(AppDark.isLight, isTrue);

      // Back to dark is kept too.
      await AppearanceSettings().saveLightMode(false);
      rows = await db.query(
        AppDatabase.metaTable,
        where: 'key = ?',
        whereArgs: [AppearanceSettings.colorModeKey],
      );
      expect(rows.single['value'], 'dark');
      expect(AppDark.isLight, isFalse);
    });

    test('is saved apart from the text size', () async {
      await AppearanceSettings().saveLightMode(true);
      await AppearanceSettings().saveTextSize(AppTextSize.large);

      _resetMode();
      AppearanceSettings.textSize.value = AppTextSize.standard;
      await AppearanceSettings().load();

      expect(AppearanceSettings.lightMode.value, isTrue);
      expect(AppearanceSettings.textSize.value, AppTextSize.large);
    });

    test('is not carried by a backup', () async {
      await StudentStorage().insert(const Student(name: 'Ana Cruz'));
      await AppearanceSettings().saveLightMode(true);

      final text = String.fromCharCodes(await BackupService().exportBytes());

      expect(text.contains(AppearanceSettings.colorModeKey), isFalse);
    });

    test('the palette follows the mode', () {
      expect(AppDark.background.toARGB32(), 0xFF0B1220);
      expect(AppDark.surface.toARGB32(), 0xFF111B2F);
      expect(AppDark.textPrimary.toARGB32(), 0xFFFFFFFF);

      AppDark.isLight = true;
      expect(AppDark.background.toARGB32(), 0xFFF2F4F8);
      expect(AppDark.surface.toARGB32(), 0xFFFFFFFF);
      expect(AppDark.textPrimary.toARGB32(), 0xFF0F172A);

      // The header is the dark brand bar in both modes.
      expect(AppDark.headerTop.toARGB32(), 0xFF1D1020);
      expect(AppDark.headerBottom.toARGB32(), 0xFF0F1626);
    });

    test('text can be read on every surface, in both modes', () {
      for (final light in [false, true]) {
        AppDark.isLight = light;
        final mode = light ? 'light' : 'dark';
        final surfaces = {
          'the page': AppDark.background,
          'a card': AppDark.surface,
          'a plate': AppDark.surfaceHigh,
        };
        surfaces.forEach((name, surface) {
          expect(
            _contrast(AppDark.textPrimary, surface),
            greaterThanOrEqualTo(7),
            reason: 'main text on $name, $mode mode',
          );
          expect(
            _contrast(AppDark.textSecondary, surface),
            greaterThanOrEqualTo(4.5),
            reason: 'quiet text on $name, $mode mode',
          );
          // The accent is mostly used for icons and large labels.
          expect(
            _contrast(AppDark.crimson, surface),
            greaterThanOrEqualTo(3),
            reason: 'the accent on $name, $mode mode',
          );
        });
        for (final entry in {
          'the soft accent': AppDark.rose,
          'the error red': AppDark.error,
          'the success green': AppDark.success,
        }.entries) {
          expect(
            _contrast(entry.value, AppDark.surface),
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key} on a card, $mode mode',
          );
          expect(
            _contrast(entry.value, AppDark.background),
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key} on the page, $mode mode',
          );
        }
      }
    });

    test('medal colours stay readable on a light card', () {
      const medals = [Color(0xFFF5C518), Color(0xFFC0C0C0), Color(0xFFCD7F32)];

      for (final medal in medals) {
        // The dark mode keeps them as they are.
        expect(AppDark.readable(medal), medal);
      }

      AppDark.isLight = true;
      for (final medal in medals) {
        expect(
          _contrast(AppDark.readable(medal), AppDark.surface),
          greaterThanOrEqualTo(4.5),
          reason: 'medal ${medal.toARGB32().toRadixString(16)}',
        );
      }
    });

    testWidgets('Appearance has a Light mode switch, off by default', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      await _openAppearance(tester);

      expect(find.text('THEME'), findsOneWidget);
      expect(find.text('Light mode'), findsOneWidget);
      expect(find.text('Off \u00B7 dark pages'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('turning it on changes the palette at once and keeps it', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      await _openAppearance(tester);

      await tester.tap(find.byType(Switch));
      await _settle(tester);

      expect(AppearanceSettings.lightMode.value, isTrue);
      expect(AppDark.isLight, isTrue);
      expect(AppDark.background.toARGB32(), 0xFFF2F4F8);
      expect(
        find.text('On \u00B7 bright pages, dark header'),
        findsOneWidget,
      );
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      // It is saved on the device, not only held in memory.
      final db = await tester.runAsync(() => AppDatabase.instance.database);
      final rows = await tester.runAsync(
        () => db!.query(
          AppDatabase.metaTable,
          where: 'key = ?',
          whereArgs: [AppearanceSettings.colorModeKey],
        ),
      );
      expect(rows!.single['value'], 'light');

      // The whole card is the button, so tapping its text turns it off again.
      await tester.tap(find.text('Light mode'));
      await _settle(tester);
      expect(AppearanceSettings.lightMode.value, isFalse);
      expect(AppDark.isLight, isFalse);
      expect(find.text('Off \u00B7 dark pages'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the Settings row says which mode is in use', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      await _openSettings(tester);
      expect(find.text('Dark mode \u00B7 Default text'), findsOneWidget);

      await tester.tap(find.text('Appearance'));
      await _settle(tester);
      await tester.tap(find.byType(Switch));
      await _settle(tester);
      await tester.tap(find.byTooltip('Back'));
      await _settle(tester);

      expect(find.text('Light mode \u00B7 Default text'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the Settings page', () {
    testWidgets('has Trash, Data and Appearance, each in its own group', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      await _openSettings(tester);

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('RECORDS'), findsOneWidget);
      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('Trash'), findsOneWidget);
      expect(find.text('Data'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('No deleted students'), findsOneWidget);
      expect(find.text('Dark mode \u00B7 Default text'), findsOneWidget);
      // The Trash is no longer a button in the header.
      expect(find.byTooltip('Trash'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every row is a touch target of at least 48', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      await _openSettings(tester);

      for (final title in ['Trash', 'Data', 'Appearance']) {
        final row = find.ancestor(
          of: find.text(title),
          matching: find.byType(InkWell),
        );
        expect(row, findsOneWidget, reason: title);
        expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(row).width, greaterThan(300));
      }
    });

    testWidgets('the Trash row counts the deleted students and opens the Trash',
        (WidgetTester tester) async {
      _phone(tester);
      await tester.runAsync(() async {
        final saved = await StudentStorage().insert(
          const Student(name: 'Nguyen Van A'),
        );
        await StudentStorage().moveToTrash(saved.id!);
      });
      await _openSettings(tester);

      expect(find.text('1 deleted student'), findsOneWidget);

      await tester.tap(find.text('Trash'));
      await _settle(tester);
      expect(find.text('Nguyen Van A'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);

      // Restoring there is reflected here once the page is closed.
      await tester.tap(find.text('Restore'));
      await _settle(tester);
      await tester.tap(find.byTooltip('Back'));
      await _settle(tester);
      expect(find.text('No deleted students'), findsOneWidget);
    });

    testWidgets('the Data row warns while a backup is due', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      await tester.runAsync(
        () => StudentStorage().insert(const Student(name: 'Ana Cruz')),
      );
      await _openSettings(tester);

      expect(find.text('Backup due'), findsOneWidget);

      await tester.runAsync(() => BackupService().markExported());
      await _openSettings(tester);
      expect(find.text('Backup due'), findsNothing);
    });

    testWidgets('the Data row opens the backup page and a Back button returns',
        (WidgetTester tester) async {
      _phone(tester);
      await _openSettings(tester);

      await tester.tap(find.text('Data'));
      await _settle(tester);
      expect(find.text('Import / Export Data'), findsOneWidget);
      expect(find.text('Export backup'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await _settle(tester);
      expect(find.text('RECORDS'), findsOneWidget);
    });

    testWidgets('a page opened from Settings tells the shell when it closes', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      var returned = 0;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SettingsScreen(onReturn: () => returned++)),
        ),
      );
      await _settle(tester);

      await tester.tap(find.text('Appearance'));
      await _settle(tester);
      expect(returned, 0);

      await tester.tap(find.byTooltip('Back'));
      await _settle(tester);
      expect(returned, 1);
    });

    testWidgets('Appearance changes the text size at once and keeps it', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      await _openSettings(tester);

      await tester.tap(find.text('Appearance'));
      await _settle(tester);
      expect(find.text('TEXT SIZE'), findsOneWidget);
      for (final label in ['Small', 'Default', 'Large', 'Extra large']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }

      await tester.tap(find.text('Large'));
      await _settle(tester);
      expect(AppearanceSettings.textSize.value, AppTextSize.large);

      // It is saved on the device, not only held in memory.
      final db = await tester.runAsync(() => AppDatabase.instance.database);
      final rows = await tester.runAsync(
        () => db!.query(
          AppDatabase.metaTable,
          where: 'key = ?',
          whereArgs: [AppearanceSettings.textSizeKey],
        ),
      );
      expect(rows!.single['value'], 'large');

      // The Settings row says what is in use.
      await tester.tap(find.byTooltip('Back'));
      await _settle(tester);
      expect(find.text('Dark mode \u00B7 Large text'), findsOneWidget);
    });
  });
}
