import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_dark.dart';

/// The loading screen is the brand screen, so it is the same dark navy in the
/// dark and the light mode alike (the palette's own colours turn light in the
/// light mode, and this screen is also the first thing drawn, before the saved
/// mode has been read).
const Color _bg = Color(0xFF0B1220);
const Color _plate = Color(0xFF111B2F);
const Color _line = Color(0xFF26324D);
const Color _text = Colors.white;
const Color _muted = Color(0xFF94A3B8);
const Color _accent = Color(0xFFE5334B);

/// The loading screen shown while the app opens: the app icon on a soft crimson
/// glow, the app name and a thin line filling up, on the same dark navy as the
/// rest of the app.
///
/// It is the first thing the owner sees and it stays up for [minimumDuration]
/// counted from the moment the app started, however long opening the database
/// took — so the wait is about three seconds in total and never much longer.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onFinished});

  /// How long the whole opening sequence lasts, from the first frame of the
  /// first splash to the Security screen.
  static const Duration minimumDuration = Duration(seconds: 3);

  /// The moment the first splash of this run was built. Recorded when the
  /// splash appears, so the screens after it can work out how long is left.
  static DateTime? startedAt;

  /// Called once [minimumDuration] has passed since [startedAt]. The gate that
  /// shows the splash listens to it to move on.
  final void Function()? onFinished;

  /// How much of [minimumDuration] is left, never less than zero.
  static Duration get remaining {
    final started = startedAt;
    if (started == null) return minimumDuration;
    final left = minimumDuration - DateTime.now().difference(started);
    return left.isNegative ? Duration.zero : left;
  }

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    SplashScreen.startedAt ??= DateTime.now();
    final left = SplashScreen.remaining;

    // The icon eases in over the first part of the wait, and the line at the
    // bottom fills for as long as the sequence lasts: a loading screen that is
    // clearly loading, with nothing that has to be watched.
    _controller = AnimationController(
      vsync: this,
      duration: left == Duration.zero ? const Duration(milliseconds: 1) : left,
    )..forward();

    if (left == Duration.zero) {
      // Already longer than it should be; hand over as soon as this frame is
      // drawn, so the callback cannot run while the widget is still building.
      _timer = Timer(Duration.zero, _finish);
    } else {
      _timer = Timer(left, _finish);
    }
  }

  void _finish() {
    if (!mounted) return;
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The line is driven by the same clock as the wait, so it reaches the end
    // exactly when the Security screen is due — no separate rebuilds, no
    // guessing how far along it is.
    final appear = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.3, curve: Curves.easeOut),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _bg,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // A soft crimson glow behind the icon, fading into the page.
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.25),
                    radius: 0.85,
                    colors: [Color(0x40E5334B), Color(0x00E5334B)],
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: appear,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.94,
                          end: 1,
                        ).animate(appear),
                        child: Container(
                          width: 132,
                          height: 132,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: _plate,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: _line),
                            boxShadow: AppDark.crimsonGlow,
                          ),
                          // The same picture the phone shows for the app. Falls
                          // back to the drawn TKD mark if the asset cannot be
                          // read, so a missing file never leaves an empty
                          // splash screen.
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const _FallbackMark(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'TKD Records',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Student Registry',
                      style: TextStyle(
                        fontSize: 14,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: 160,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) => LinearProgressIndicator(
                            value: _controller.value,
                            minHeight: 4,
                            backgroundColor: _line,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              _accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The TKD mark, drawn rather than loaded, used only when the icon file is not
/// there to be read: white letters on the crimson gradient.
class _FallbackMark extends StatelessWidget {
  const _FallbackMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppDark.crimsonGradient),
      alignment: Alignment.center,
      child: const Text(
        'TKD',
        style: TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
