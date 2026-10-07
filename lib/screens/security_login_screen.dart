import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/security_service.dart';
import '../theme/app_dark.dart';
import '../widgets/app_page.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/registry_header.dart';
import '../widgets/security_fields.dart';

/// Every launch: the owner enters the security password before the registry
/// opens. There is no user name.
///
/// The check runs on this device, so it works with no internet and after a
/// restart.
class SecurityLoginScreen extends StatefulWidget {
  const SecurityLoginScreen({super.key, required this.onSignedIn});

  /// Called once the password has been accepted, to show the registry.
  final VoidCallback onSignedIn;

  @override
  State<SecurityLoginScreen> createState() => _SecurityLoginScreenState();
}

class _SecurityLoginScreenState extends State<SecurityLoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _password = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final bool accepted;
    try {
      accepted = await SecurityService.instance.signIn(
        password: _password.text,
      );
    } on SignInLockedException catch (locked) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            'Too many wrong attempts. Try again in '
            '${_describe(locked.remaining)}.';
        _password.clear();
      });
      return;
    } catch (_) {
      // The database could not be read. Say so rather than claiming the
      // password was wrong.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not check the password. Please try again.';
      });
      return;
    }

    if (!mounted) return;
    if (accepted) {
      widget.onSignedIn();
      return;
    }
    final wait = await SecurityService.instance.lockoutRemaining();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = wait > Duration.zero
          ? 'Too many wrong attempts. Try again in ${_describe(wait)}.'
          : 'Incorrect password.';
      // Nothing is kept of a failed attempt: the password is cleared.
      _password.clear();
    });
  }

  /// A pause as words: "45 seconds", "2 minutes", "1 hour".
  static String _describe(Duration wait) {
    if (wait.inSeconds < 60) {
      final seconds = wait.inSeconds < 1 ? 1 : wait.inSeconds;
      return '$seconds second${seconds == 1 ? '' : 's'}';
    }
    if (wait.inMinutes < 60) {
      final minutes = (wait.inSeconds / 60).ceil();
      return '$minutes minute${minutes == 1 ? '' : 's'}';
    }
    final hours = (wait.inMinutes / 60).ceil();
    return '$hours hour${hours == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppDark.navBar,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppDark.headerBottom,
        body: Column(
          children: [
            // The logo header, the same one the registry opens with.
            const RegistryHeader(),
            Expanded(
              child: AppSheet(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  children: [
                    const PageIntro(
                      title: 'Security Login',
                      subtitle: 'Enter the password to open the registry',
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      NoticeCard(icon: Icons.error_outline, message: _error!),
                      const SizedBox(height: 14),
                    ],
                    Form(
                      key: _formKey,
                      child: DarkCard(
                        accent: AppDark.crimson,
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                IconPlate(icon: Icons.lock_outline),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Security Password',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppDark.textPrimary,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Locks the registry on this device',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppDark.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            SecurityTextField(
                              controller: _password,
                              label: 'Password',
                              hint: 'Enter password',
                              obscured: true,
                              autofocus: true,
                              textInputAction: TextInputAction.done,
                              validator: (value) =>
                                  (value == null || value.isEmpty)
                                  ? 'Password is required'
                                  : null,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const NoticeCard(
                      icon: Icons.wifi_off_outlined,
                      message:
                          'Checked on this device only. No internet is needed, '
                          'nothing is sent anywhere, and the password is never '
                          'stored as you typed it. It locks the app — keep your '
                          'phone lock screen on too, since that is what guards '
                          'the saved file.',
                    ),
                  ],
                ),
              ),
            ),
            AppActionBar(
              child: CrimsonButton(
                label: _busy ? 'Checking…' : 'Log In',
                icon: Icons.login_outlined,
                busy: _busy,
                expand: true,
                onPressed: _busy ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
