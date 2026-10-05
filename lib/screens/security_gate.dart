import 'package:flutter/material.dart';

import 'security_login_screen.dart';
import 'splash_screen.dart';

/// The opening sequence: loading screen, then the security password, then the
/// app.
///
/// There is nothing to set up: the password is built into the app, so every
/// launch goes loading screen → Security Login → registry. The login screen
/// cannot be backed out of, because it is the root of the stack: the registry
/// is never shown without the password being entered first.
class SecurityGate extends StatefulWidget {
  const SecurityGate({super.key, required this.child});

  /// The registry, built only once the password has been accepted.
  final Widget child;

  /// Test-only switch: the widget tests are about the records, not about
  /// signing in, so they start with the lock already open. Production code
  /// never sets it.
  @visibleForTesting
  static bool debugSkipLock = false;

  @override
  State<SecurityGate> createState() => _SecurityGateState();
}

enum _Phase { splash, login, open }

class _SecurityGateState extends State<SecurityGate> {
  _Phase _phase = _Phase.splash;

  /// Called by the loading screen when the three seconds are up.
  void _afterSplash() {
    if (!mounted) return;
    setState(() => _phase = _Phase.login);
  }

  void _unlocked() {
    if (!mounted) return;
    setState(() => _phase = _Phase.open);
  }

  @override
  Widget build(BuildContext context) {
    if (SecurityGate.debugSkipLock) return widget.child;

    switch (_phase) {
      case _Phase.splash:
        return SplashScreen(onFinished: _afterSplash);
      case _Phase.login:
        return SecurityLoginScreen(onSignedIn: _unlocked);
      case _Phase.open:
        return widget.child;
    }
  }
}
