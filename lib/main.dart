import 'dart:io';

import 'package:flutter/material.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'screens/achievement_screen.dart';
import 'screens/data_transfer_screen.dart';
import 'screens/promotion_screen.dart';
import 'screens/students_screen.dart';
import 'services/app_database.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final db = await AppDatabase.instance.database;
  debugPrint('DB tables: ${await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table'",
  )}');
  debugPrint('Foreign keys: ${await db.rawQuery('PRAGMA foreign_keys')}');

  runApp(const TkdApp());
}

class TkdApp extends StatelessWidget {
  const TkdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TKD Records',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Bumped on every destination change. The [IndexedStack] keeps all four
  /// screens alive, so a screen that reads saved files (the Achievement list)
  /// uses this signal to refresh each time the user comes back to it.
  int _visits = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const StudentsScreen(),
          const PromotionScreen(),
          AchievementScreen(visits: _visits),
          const DataTransferScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() {
            _index = i;
            _visits++;
          }),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          elevation: 0,
          selectedItemColor: AppColors.red,
          unselectedItemColor: AppColors.muted,
          selectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.groups_outlined),
              label: 'Students',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_outlined),
              label: 'Promotion',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.workspace_premium_outlined),
              label: 'Achievement',
            ),
            // Kept short so the bar stays readable on narrow phones; the
            // screen itself carries the full "Import / Export Data" title.
            BottomNavigationBarItem(
              icon: Icon(Icons.swap_horiz_outlined),
              label: 'Data',
            ),
          ],
        ),
      ),
    );
  }
}
