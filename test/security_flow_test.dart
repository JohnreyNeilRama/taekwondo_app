import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/main.dart';
import 'package:tkd_app/screens/security_gate.dart';
import 'package:tkd_app/screens/splash_screen.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/security_service.dart';

/// Cheap derivation cost while tests run; the app's own setting would make
/// every sign-in in a test take about a second.
const int _cheap = 1000;

/// The built-in security password the app ships with.
const String _password = 'TkD_Gu@d@!';

/// What the gate opens once the password is accepted. Stand-in for the
/// registry, so these tests are about the security screens rather than about
/// the records.
const String _registryMark = 'Registry open';

/// A credential for [_password] with a cheap derivation, used in place of the
/// built-in one so a sign-in in a test does not wait for the real cost.
SecurityCredential _cheapCredential() {
  final salt = Uint8List.fromList(List<int>.generate(16, (i) => i + 1));
  return SecurityCredential(
    iterations: _cheap,
    salt: salt,
    hash: deriveKey(
      password: Uint8List.fromList(utf8.encode(_password)),
      salt: salt,
      iterations: _cheap,
      keyBytes: 32,
    ),
  );
}

/// Gives the test its own empty in-memory database and starts the opening
/// sequence over, the way a launch would.
Future<void> _fresh(WidgetTester tester) async {
  await tester.runAsync(() async {
    await AppDatabase.debugReset();
    AppDatabase.debugOverridePath = inMemoryDatabasePath;
  });
  SecurityGate.debugSkipLock = false;
  SecurityService.debugCredential = _cheapCredential();
  // The three seconds are measured from here, so a test cannot inherit the
  // remaining time of the test before it.
  SplashScreen.startedAt = null;
}

/// Flushes both kinds of async work this app relies on: real SQLite and the
/// hashing isolate, which only answer on the real event loop, and frames,
/// which advance on the fake clock.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 14; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Pumps the gate, with a MaterialApp around it the way the app has one, so the
/// security screens have a navigator and a messenger to work with. [child] is
/// what the gate opens once the password is accepted; the marker stands in for
/// the registry unless a test asks for the real one.
Future<void> _pumpGate(WidgetTester tester, {Widget? child}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SecurityGate(
        child:
            child ?? const Scaffold(body: Center(child: Text(_registryMark))),
      ),
    ),
  );
}

/// Waits out the loading screen.
Future<void> _pastSplash(WidgetTester tester) async {
  await tester.pump(SplashScreen.minimumDuration);
  await _settle(tester);
}

/// The one input of the Security Login screen.
Finder get _passwordField => find.byType(TextFormField);

/// Types [password] into the field and presses Log In.
Future<void> _logIn(WidgetTester tester, String password) async {
  await tester.enterText(_passwordField, password);
  await tester.pump();
  await tester.tap(find.text('Log In'));
  await _settle(tester);
}

void main() {
  setUpAll(() {
    // The attempt counter lives in the app's own SQLite database, opened
    // through the FFI implementation because the platform channels are not
    // running.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await AppDatabase.debugReset();
    SecurityService.debugCredential = null;
    SecurityGate.debugSkipLock = false;
    SplashScreen.startedAt = null;
  });

  group('the loading screen', () {
    testWidgets('shows the app icon, then goes straight to the password', (
      WidgetTester tester,
    ) async {
      await _fresh(tester);
      await _pumpGate(tester);

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('TKD Records'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // Nothing of the registry is open yet.
      expect(find.text(_registryMark), findsNothing);

      // Three seconds and it hands over to Security Login: there is nothing to
      // set up first.
      await _pastSplash(tester);

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.text('Security Login'), findsOneWidget);
      expect(find.text('Set Up Security Account'), findsNothing);
    });
  });

  group('the Security Login screen', () {
    testWidgets('asks for a password only, with a Log In button', (
      WidgetTester tester,
    ) async {
      await _fresh(tester);
      await _pumpGate(tester);
      await _pastSplash(tester);

      // One input, and it is the password: no user name.
      expect(_passwordField, findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('User Name'), findsNothing);
      expect(find.text('Log In'), findsOneWidget);
      expect(find.text(_registryMark), findsNothing);
    });

    testWidgets('an empty password is refused before anything is checked', (
      WidgetTester tester,
    ) async {
      await _fresh(tester);
      await _pumpGate(tester);
      await _pastSplash(tester);

      await tester.tap(find.text('Log In'));
      await _settle(tester);

      expect(find.text('Password is required'), findsOneWidget);
      expect(find.text(_registryMark), findsNothing);
    });

    testWidgets('a wrong password gets nowhere and leaves nothing behind', (
      WidgetTester tester,
    ) async {
      await _fresh(tester);
      await _pumpGate(tester);
      await _pastSplash(tester);

      await _logIn(tester, 'not the password');

      expect(find.text('Incorrect password.'), findsOneWidget);
      expect(find.text(_registryMark), findsNothing);
      // The password that was tried is cleared, so it is not left sitting on
      // the screen for the next person who picks up the phone.
      expect(
        tester.widget<TextFormField>(_passwordField).controller!.text,
        isEmpty,
      );
    });

    testWidgets('the built-in password opens the app', (
      WidgetTester tester,
    ) async {
      await _fresh(tester);
      await _pumpGate(tester);
      await _pastSplash(tester);

      await _logIn(tester, _password);

      expect(find.text(_registryMark), findsOneWidget);
      expect(find.text('Security Login'), findsNothing);
    });

    testWidgets('the next launch asks for the password again', (
      WidgetTester tester,
    ) async {
      await _fresh(tester);
      await _pumpGate(tester);
      await _pastSplash(tester);
      await _logIn(tester, _password);
      expect(find.text(_registryMark), findsOneWidget);

      // Opened again the way a new launch would be: the old tree has to be
      // dropped first, so a new gate starts from its own loading screen rather
      // than being handed the state of the one before it.
      SplashScreen.startedAt = null;
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
      await _pumpGate(tester);
      await _pastSplash(tester);

      expect(find.text('Security Login'), findsOneWidget);
      expect(find.text(_registryMark), findsNothing);
    });

    testWidgets('too many wrong attempts pause sign-in', (
      WidgetTester tester,
    ) async {
      await _fresh(tester);
      await _pumpGate(tester);
      await _pastSplash(tester);

      for (var attempt = 0; attempt < SecurityService.freeAttempts; attempt++) {
        await _logIn(tester, 'wrong $attempt');
      }
      expect(find.textContaining('Too many wrong attempts'), findsOneWidget);

      // Even the right password waits until the pause is over.
      await _logIn(tester, _password);
      expect(find.textContaining('Too many wrong attempts'), findsOneWidget);
      expect(find.text(_registryMark), findsNothing);
    });
  });

  group('the app shell', () {
    testWidgets('opens behind the password with four destinations, no Profile', (
      WidgetTester tester,
    ) async {
      // The width of an ordinary phone, so the bar is checked at the size it
      // really has to fit.
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _fresh(tester);
      await tester.runAsync(() => AppDatabase.instance.database);

      // The real registry behind the gate, so the bar is the one in the app.
      await _pumpGate(tester, child: const HomeShell());
      await _pastSplash(tester);
      await _logIn(tester, _password);

      final bar = find.byType(BottomNavigationBar);
      expect(bar, findsOneWidget);
      for (final label in ['Students', 'Promotion', 'Achievement', 'Data']) {
        expect(
          find.descendant(of: bar, matching: find.text(label)),
          findsOneWidget,
          reason: '$label should be on the bottom bar',
        );
      }
      // The Profile destination is gone, and its Security section with it.
      expect(find.text('Profile'), findsNothing);
      expect(find.text('Change Password'), findsNothing);
      expect(
        tester.widget<BottomNavigationBar>(bar).items,
        hasLength(4),
      );
      // Four labels fit the bar without pushing anything out of it.
      expect(tester.takeException(), isNull);

      // Every remaining destination still opens.
      for (final label in ['Promotion', 'Achievement', 'Data', 'Students']) {
        await tester.tap(find.text(label).last);
        await _settle(tester);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
