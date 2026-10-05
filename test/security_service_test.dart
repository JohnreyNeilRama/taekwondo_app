import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/backup_service.dart';
import 'package:tkd_app/services/security_service.dart';

/// Lower than the app's own cost, so the lockout tests stay fast. What is
/// being checked there is the behaviour, not how long the derivation takes.
const int _cheap = 1000;

/// The built-in security password the app ships with.
const String _password = 'TkD_Gu@d@!';

/// The password the app used before the built-in one. It must not open the app.
const String _oldPassword = 'Taekwondo#2026';

/// Bytes of [text], straight through UTF-8, so a password with an accented
/// letter or a symbol is derived the same way the app derives it.
Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

String _hex(List<int> bytes) =>
    [for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0')].join();

/// A credential for [_password] with a cheap derivation, used in place of the
/// built-in one by the tests that need many sign-ins.
SecurityCredential _cheapCredential() {
  final salt = Uint8List.fromList(List<int>.generate(16, (i) => i + 1));
  return SecurityCredential(
    iterations: _cheap,
    salt: salt,
    hash: deriveKey(
      password: _bytes(_password),
      salt: salt,
      iterations: _cheap,
      keyBytes: 32,
    ),
  );
}

void main() {
  setUpAll(() {
    // The attempt counter lives in the app's SQLite database, which in a test
    // is opened through the FFI implementation instead of a platform channel.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.debugReset();
    AppDatabase.debugOverridePath = inMemoryDatabasePath;
    SecurityService.debugCredential = null;
  });

  tearDown(() async {
    await AppDatabase.debugReset();
    SecurityService.debugCredential = null;
  });

  group('the key derivation', () {
    // Vectors produced with an independent PBKDF2-HMAC-SHA256 implementation
    // (Python's hashlib.pbkdf2_hmac), so this checks the app's own loop against
    // something that shares none of its code.
    test('matches the published PBKDF2-HMAC-SHA256 vectors', () {
      expect(
        _hex(
          deriveKey(
            password: _bytes('password'),
            salt: _bytes('salt'),
            iterations: 1,
            keyBytes: 32,
          ),
        ),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
      expect(
        _hex(
          deriveKey(
            password: _bytes('password'),
            salt: _bytes('salt'),
            iterations: 2,
            keyBytes: 32,
          ),
        ),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
      expect(
        _hex(
          deriveKey(
            password: _bytes('password'),
            salt: _bytes('salt'),
            iterations: 4096,
            keyBytes: 32,
          ),
        ),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });

    test('matches for a key longer than one block', () {
      expect(
        _hex(
          deriveKey(
            password: _bytes('passwordPASSWORDpassword'),
            salt: _bytes('saltSALTsaltSALTsaltSALTsaltSALTsalt'),
            iterations: 4096,
            keyBytes: 40,
          ),
        ),
        '348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c4e2a1fb8dd53e1'
        'c635518c7dac47e9',
      );
    });

    test('matches for a password and salt holding a zero byte', () {
      expect(
        _hex(
          deriveKey(
            password: Uint8List.fromList([
              ..._bytes('pass'),
              0,
              ..._bytes('word'),
            ]),
            salt: Uint8List.fromList([..._bytes('sa'), 0, ..._bytes('lt')]),
            iterations: 4096,
            keyBytes: 16,
          ),
        ),
        '89b69d0516f829893c696226650a8687',
      );
    });

    test('matches for a password outside ASCII, and for an empty one', () {
      expect(
        _hex(
          deriveKey(
            password: _bytes('Pässword1234!'),
            salt: _bytes('tkd-salt'),
            iterations: 5000,
            keyBytes: 32,
          ),
        ),
        'cef42e0cc71bf2d96492bf716fc7db64112b8ea20ec38492d56060b18a2b695a',
      );
      expect(
        _hex(
          deriveKey(
            password: Uint8List(0),
            salt: Uint8List(0),
            iterations: 1,
            keyBytes: 32,
          ),
        ),
        'f7ce0b653d2d72a4108cf5abe912ffdd777616dbbb27a70e8204f3ae2d0f6fad',
      );
    });
  });

  group('the built-in password', () {
    // These use the real built-in credential, at its real cost, so they check
    // exactly what ships.
    test('the right password is accepted', () async {
      expect(await SecurityService.instance.signIn(password: _password), isTrue);
    });

    test('any other password is refused', () async {
      final service = SecurityService.instance;

      // Empty, a common word, the password the app used before, a wrong case
      // and a partial word: none of them may open the app. The right password
      // is typed between the wrong ones on purpose — each sign-in with it
      // clears the count of wrong attempts, so the test never reaches the pause
      // that "too many wrong attempts" covers, and every case is checked from a
      // clean slate.
      final List<String> wrong = [
        '',
        'password',
        _oldPassword,
        // The password is case sensitive and has to match in full.
        _password.toUpperCase(),
        _password.toLowerCase(),
        _password.substring(1),
        '$_password ',
      ];

      for (final attempt in wrong) {
        expect(await service.signIn(password: attempt), isFalse);
        expect(await service.signIn(password: _password), isTrue);
      }
    });

    test('needs no user name and no setup, even on a fresh device', () async {
      // A brand new, empty database: nothing was ever created, yet the
      // password works.
      expect(await SecurityService.instance.signIn(password: _password), isTrue);
    });

    test('the password is not stored in any readable form', () async {
      final credential = SecurityService.builtIn;
      final stored = utf8.decode(
        [...credential.salt, ...credential.hash],
        allowMalformed: true,
      );
      expect(stored, isNot(contains(_password)));
      expect(credential.hash, hasLength(32));
      expect(credential.iterations, SecurityService.iterations);

      // Signing in, rightly and wrongly, leaves nothing of the password in the
      // database either.
      final service = SecurityService.instance;
      await service.signIn(password: 'not the password');
      await service.signIn(password: _password);

      final db = await AppDatabase.instance.database;
      final rows = await db.query(AppDatabase.metaTable);
      final everything = [
        for (final row in rows) '${row['key']}=${row['value']}',
      ].join('\n');
      expect(everything, isNot(contains(_password)));
      expect(everything, isNot(contains('TkD_')));
      expect(everything, isNot(contains(base64Encode(_bytes(_password)))));
    });
  });

  group('too many wrong attempts', () {
    setUp(() => SecurityService.debugCredential = _cheapCredential());

    test('sign-in pauses after the free attempts, even for the right password',
        () async {
      final service = SecurityService.instance;

      for (var attempt = 1; attempt <= SecurityService.freeAttempts; attempt++) {
        expect(await service.signIn(password: 'wrong'), isFalse);
      }

      expect(await service.lockoutRemaining(), greaterThan(Duration.zero));
      await expectLater(
        service.signIn(password: _password),
        throwsA(isA<SignInLockedException>()),
      );
    });

    test('a right password in time clears the count', () async {
      final service = SecurityService.instance;

      for (var attempt = 1; attempt < SecurityService.freeAttempts; attempt++) {
        expect(await service.signIn(password: 'wrong'), isFalse);
      }
      expect(await service.signIn(password: _password), isTrue);

      // The count starts again from nothing: the same number of misses as
      // before is not enough to pause sign-in.
      for (var attempt = 1; attempt < SecurityService.freeAttempts; attempt++) {
        expect(await service.signIn(password: 'wrong'), isFalse);
      }
      expect(await service.lockoutRemaining(), Duration.zero);
      expect(await service.signIn(password: _password), isTrue);
    });

    test('the pause ends by itself', () async {
      final service = SecurityService.instance;
      for (var attempt = 1; attempt <= SecurityService.freeAttempts; attempt++) {
        await service.signIn(password: 'wrong');
      }
      expect(await service.lockoutRemaining(), greaterThan(Duration.zero));

      // Move the end of the pause into the past, the way waiting would.
      final db = await AppDatabase.instance.database;
      await db.update(
        AppDatabase.metaTable,
        {
          'value': DateTime.now()
              .toUtc()
              .subtract(const Duration(seconds: 1))
              .toIso8601String(),
        },
        where: 'key = ?',
        whereArgs: ['security.locked_until'],
      );

      expect(await service.lockoutRemaining(), Duration.zero);
      expect(await service.signIn(password: _password), isTrue);
    });
  });

  test('a backup never carries anything of the security password', () async {
    SecurityService.debugCredential = _cheapCredential();
    final service = SecurityService.instance;
    // Leave the attempt counter in the database, so there is something under
    // the security. keys that a backup could wrongly pick up.
    await service.signIn(password: 'wrong');

    final file = utf8.decode(await BackupService().exportBytes());

    expect(file, contains('tkd_app_backup'));
    expect(file, isNot(contains('security.')));
    expect(file, isNot(contains(_password)));
    expect(file, isNot(contains('pbkdf2')));
  });
}
