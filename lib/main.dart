import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'screens/achievement_screen.dart';
import 'screens/attendance_scanner_screen.dart';
import 'screens/promotion_screen.dart';
import 'screens/security_gate.dart';
import 'screens/settings_screen.dart';
import 'screens/startup_gate.dart';
import 'screens/students_screen.dart';
import 'services/appearance_settings.dart';
import 'services/backup_service.dart';
import 'theme/app_dark.dart';
import 'theme/app_theme.dart';
import 'widgets/app_nav_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // The gate opens (and on a brand new device creates) the database before the
  // first screen asks for it, brings across the records the versions before the
  // database saved as JSON files, and shows a message with a way forward if the
  // database cannot be opened, instead of a blank screen.
  runApp(const StartupGate(child: TkdApp()));
}

class TkdApp extends StatefulWidget {
  const TkdApp({super.key});

  @override
  State<TkdApp> createState() => _TkdAppState();
}

class _TkdAppState extends State<TkdApp> {
  @override
  void initState() {
    super.initState();
    _loadAppearance();
  }

  /// Brings in the text size and the colour mode saved on this device. The app
  /// starts with the defaults and moves to the saved ones as soon as they are
  /// read; a database problem is reported by the pages that need the database,
  /// so it is not repeated here.
  Future<void> _loadAppearance() async {
    try {
      await AppearanceSettings().load();
    } catch (_) {
      // Keeps the defaults.
    }
  }

  @override
  Widget build(BuildContext context) {
    // The theme is built again whenever the colour mode changes, so the
    // controls no page styles by hand (dialogs, pickers, menus) follow it.
    return ValueListenableBuilder<bool>(
      valueListenable: AppearanceSettings.lightMode,
      builder: (context, light, _) => MaterialApp(
        title: 'Tae-Kwon-Do',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        // The palette is switched before this builds, so there is nothing to
        // fade between.
        themeAnimationDuration: Duration.zero,
        // The text size chosen under Settings > Appearance, applied to every
        // page (the security screens included) on top of the phone's own
        // setting.
        builder: (context, child) => ValueListenableBuilder<AppTextSize>(
          valueListenable: AppearanceSettings.textSize,
          child: child,
          builder: (context, size, child) {
            if (size.factor == 1) return child!;
            final media = MediaQuery.of(context);
            final system = media.textScaler.scale(16) / 16;
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(system * size.factor),
              ),
              child: child!,
            );
          },
        ),
        // The gate asks for the security password before the registry is built:
        // the loading screen first, then Security Login.
        home: SecurityGate(child: const _HomeHost()),
      ),
    );
  }
}

/// Holds the registry (the [HomeShell]) and builds it again from scratch when the
/// colour mode changes.
///
/// Pages write their colours in `const` places, and a `const` subtree is not
/// rebuilt by a parent that rebuilds, so it would keep the old palette. A new
/// key makes the shell a brand-new subtree instead. It does not touch the
/// security gate above it, so changing the mode never asks for the password
/// again, and it remembers the destination that was open so the owner comes
/// back to the same tab.
class _HomeHost extends StatefulWidget {
  const _HomeHost();

  @override
  State<_HomeHost> createState() => _HomeHostState();
}

class _HomeHostState extends State<_HomeHost> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppearanceSettings.lightMode,
      builder: (context, light, _) => HomeShell(
        key: ValueKey<bool>(light),
        initialIndex: _tab,
        onIndexChanged: (index) => _tab = index,
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0, this.onIndexChanged});

  /// The destination that is open when the shell is built. The shell is built
  /// again when the colour mode changes, and this is how it comes back to the
  /// tab that was open.
  final int initialIndex;

  /// Called with the destination every time the owner moves to another one.
  final ValueChanged<int>? onIndexChanged;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// Position of the QR button in the bottom bar: the middle of the five slots.
  /// It opens the attendance scanner instead of switching destination, so the
  /// four screens keep the indexes 0..3 inside the [IndexedStack] and only the
  /// bar positions around the button are shifted.
  static const int _scanSlot = AppNavBar.scanSlot;

  late int _index = widget.initialIndex;

  /// Bumped on every destination change. The [IndexedStack] keeps all four
  /// screens alive, so a screen that reads saved records (the Promotion and
  /// Achievement lists, the Settings rows) uses this signal to refresh each time
  /// the user comes back to it.
  int _visits = 0;

  /// Whether records are waiting to be backed up. Drives a small warning dot on
  /// the Settings tab, so the owner is reminded to export without the app taking
  /// over the data with an automatic copy. Re-read whenever the owner moves
  /// between destinations and whenever a page opened from Settings is closed, so
  /// exporting from the Data page clears it at once.
  bool _backupDue = false;

  final BackupService _backup = BackupService();

  @override
  void initState() {
    super.initState();
    _refreshBackupReminder();
  }

  /// Reads whether a backup is due and updates the tab dot. A database problem
  /// is reported where it happens (the Data page), never here.
  Future<void> _refreshBackupReminder() async {
    bool due;
    try {
      due = await _backup.reminderDue();
    } catch (_) {
      return;
    }
    if (!mounted || due == _backupDue) return;
    setState(() => _backupDue = due);
  }

  /// Opens destination [index] and records that the owner moved, the same way
  /// the bar has always done it. The reminder is re-read on every move so it
  /// reflects the latest export.
  void _select(int index) {
    setState(() {
      _index = index;
      _visits++;
    });
    widget.onIndexChanged?.call(index);
    _refreshBackupReminder();
  }

  /// The bar slot that is highlighted for the destination on screen: the slots
  /// after the QR button sit one place further right.
  int get _barIndex => _index < _scanSlot ? _index : _index + 1;

  /// A tap on the bar: the middle button opens the scanner, every other slot
  /// selects its destination.
  void _onBarTap(int barIndex) {
    if (barIndex == _scanSlot) {
      _openScanner();
      return;
    }
    _select(barIndex < _scanSlot ? barIndex : barIndex - 1);
  }

  Future<void> _openScanner() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const AttendanceScannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status-bar icons over the dark headers (the header is dark in both
      // modes), and a navigation area that blends into the bottom bar instead
      // of showing a strip of another colour under it: dark icons on the light
      // bar, light icons on the dark one.
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppDark.navBar,
        systemNavigationBarIconBrightness: AppDark.isLight
            ? Brightness.dark
            : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppDark.background,
        body: IndexedStack(
          index: _index,
          children: [
            StudentsScreen(visits: _visits),
            PromotionScreen(visits: _visits),
            AchievementScreen(visits: _visits),
            SettingsScreen(
              visits: _visits,
              onReturn: _refreshBackupReminder,
            ),
          ],
        ),
        // The dot on the Settings slot appears while records are waiting to be
        // exported, so the owner is reminded to back up.
        bottomNavigationBar: AppNavBar(
          selected: _barIndex,
          onSelected: _onBarTap,
          showSettingsBadge: _backupDue,
        ),
      ),
    );
  }
}
