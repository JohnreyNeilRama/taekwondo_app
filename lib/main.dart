import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'screens/achievement_screen.dart';
import 'screens/attendance_scanner_screen.dart';
import 'screens/data_transfer_screen.dart';
import 'screens/promotion_screen.dart';
import 'screens/security_gate.dart';
import 'screens/startup_gate.dart';
import 'screens/students_screen.dart';
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

class TkdApp extends StatelessWidget {
  const TkdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tae-Kwon-Do',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // The gate asks for the security password before the registry is built:
      // the loading screen first, then Security Login.
      home: SecurityGate(child: const HomeShell()),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// Position of the QR button in the bottom bar: the middle of the five slots.
  /// It opens the attendance scanner instead of switching destination, so the
  /// four screens keep the indexes 0..3 inside the [IndexedStack] and only the
  /// bar positions around the button are shifted.
  static const int _scanSlot = AppNavBar.scanSlot;

  int _index = 0;

  /// Bumped on every destination change. The [IndexedStack] keeps all four
  /// screens alive, so a screen that reads saved records (the Promotion and
  /// Achievement lists) uses this signal to refresh each time the user comes
  /// back to it.
  int _visits = 0;

  /// Whether records are waiting to be backed up. Drives a small warning dot on
  /// the Data tab, so the owner is reminded to export without the app taking
  /// over the data with an automatic copy. Re-read whenever the owner moves
  /// between destinations, so exporting from the Data page clears it at once.
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
      // Light status-bar icons over the dark headers, and a navigation area that
      // blends into the dark bottom bar instead of showing a white strip under
      // it.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppDark.navBar,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        // Every page now sits on the same dark navy.
        backgroundColor: AppDark.background,
        body: IndexedStack(
          index: _index,
          children: [
            StudentsScreen(visits: _visits),
            PromotionScreen(visits: _visits),
            AchievementScreen(visits: _visits),
            DataTransferScreen(visits: _visits),
          ],
        ),
        // The dot on the Data slot appears while records are waiting to be
        // exported, so the owner is reminded to back up.
        bottomNavigationBar: AppNavBar(
          selected: _barIndex,
          onSelected: _onBarTap,
          showDataBadge: _backupDue,
        ),
      ),
    );
  }
}
