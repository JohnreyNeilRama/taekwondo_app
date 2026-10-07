import 'package:flutter/material.dart';

import '../services/app_database.dart';
import '../services/legacy_json_import.dart';
import '../services/student_storage.dart';
import '../theme/app_dark.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page.dart';
import 'splash_screen.dart';

/// Opens the database before the first screen and shows [child] once it is
/// ready.
///
/// If the database cannot be opened (a damaged file, no free space, a missing
/// folder) the owner sees a message with a way forward instead of a blank
/// screen: try again, or set the damaged file aside and start with an empty
/// registry. The damaged file is moved, never deleted.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key, required this.child});

  /// The app itself, built only after the database is open.
  final Widget child;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

enum _Phase { opening, ready, failed }

class _StartupGateState extends State<StartupGate> {
  _Phase _phase = _Phase.opening;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      await AppDatabase.instance.database;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = error;
      });
      return;
    }

    // Brings across the records the versions before the database saved as JSON
    // files; on a phone there are none. A problem here must never lock the
    // owner out of the records the database already holds, so it is not fatal.
    try {
      await LegacyJsonImporter().importIfNeeded();
    } catch (_) {}

    // Stamps a stable identity on every student saved before uids existed, so a
    // backup made here — and one imported from another device — recognise the
    // same person even after a rename or a renumbering. Only rows without one
    // are looked at, so after the first launch this is a single cheap query.
    // Like the import above, a failure here must never keep the owner out of
    // the app.
    try {
      await StudentStorage().ensureStudentUids();
    } catch (_) {}

    // Converts the full-size pictures an older version saved into compact ones,
    // so the lists stop loading megabytes of photo per student. Only rows with
    // no separate original are touched, so once a registry is converted this is
    // a single cheap query. Like the import above, a failure here must never
    // keep the owner out of the app: the pictures simply stay as they were.
    try {
      await StudentStorage().shrinkLargePhotos();
    } catch (_) {}

    // Packs the registry numbers into TKD-0001..M, closing any gap an older
    // version left and any number a backup brought from another device. Students
    // in the Trash keep their place in the sequence. Safe to run every launch:
    // a registry that is already correct is left untouched, and a failure here
    // must never keep the owner out of the app.
    try {
      await StudentStorage().renumberStudents();
    } catch (_) {}

    if (!mounted) return;
    setState(() => _phase = _Phase.ready);
  }

  void _tryAgain() {
    setState(() {
      _phase = _Phase.opening;
      _error = null;
    });
    _open();
  }

  Future<void> _startFresh() async {
    setState(() {
      _phase = _Phase.opening;
      _error = null;
    });
    try {
      await AppDatabase.instance.recoverFromUnopenableFile();
    } catch (_) {
      // If the file cannot be moved, opening it again reports the same error.
    }
    await _open();
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.ready:
        return widget.child;
      case _Phase.opening:
        // The branded loading screen, so the three seconds start here rather
        // than after the database is open — however long opening takes, the
        // Security screen is due about three seconds after launch.
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: const SplashScreen(),
        );
      case _Phase.failed:
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: _StartupFailure(
            error: _error,
            onTryAgain: _tryAgain,
            onStartFresh: _startFresh,
          ),
        );
    }
  }
}

class _StartupFailure extends StatelessWidget {
  const _StartupFailure({
    required this.error,
    required this.onTryAgain,
    required this.onStartFresh,
  });

  final Object? error;
  final VoidCallback onTryAgain;
  final VoidCallback onStartFresh;

  Future<void> _confirmStartFresh(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start with an empty registry?'),
        content: const Text(
          'The damaged file is not deleted: it is set aside next to the '
          'database, so the records in it can still be recovered by hand. '
          'The app then starts with an empty registry.',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppDark.icon),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppDark.crimson),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Start empty'),
          ),
        ],
      ),
    );
    if (confirmed == true) onStartFresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDark.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DarkCard(
                accent: AppDark.crimson,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: IconPlate(
                        icon: Icons.error_outline,
                        size: 64,
                        color: AppDark.crimson,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'The registry could not be opened',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: AppDark.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your records are not deleted. Check that the device has '
                      'free space, then try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppDark.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    CrimsonButton(
                      label: 'Try again',
                      icon: Icons.refresh,
                      expand: true,
                      onPressed: onTryAgain,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => _confirmStartFresh(context),
                      child: const Text('Set the file aside and start empty'),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        '$error',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppDark.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
