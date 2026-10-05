import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// Thrown by [SecurityService.signIn] while sign-in is paused after too many
/// wrong attempts. [remaining] is how long is left of the pause.
class SignInLockedException implements Exception {
  const SignInLockedException(this.remaining);

  final Duration remaining;

  @override
  String toString() => 'Sign-in is paused for $remaining';
}

/// The values a password is checked against: a salt, the number of derivation
/// rounds and the key those produce for the right password. The password
/// itself is never part of it, in any form.
class SecurityCredential {
  const SecurityCredential({
    required this.iterations,
    required this.salt,
    required this.hash,
  });

  final int iterations;
  final Uint8List salt;
  final Uint8List hash;
}

/// The security password of this app: one built-in password, asked for before
/// the registry is shown. There is no user name, nothing to set up and no way
/// to change it from inside the app.
///
/// The password is not written anywhere in the app, not in the code and not in
/// the database. What the app carries is a key derived from it with
/// PBKDF2-HMAC-SHA256 (RFC 8018) and a random salt: the same password typed
/// again derives the same key, and nobody can go back from the key to the
/// password.
///
/// Everything happens on the device. There is no network and no service to
/// reach, so the check keeps working with the phone offline and after a
/// restart.
///
/// The only thing saved at run time is the count of wrong attempts and the end
/// of a pause, in the `app_meta` table the database already has, under the
/// `security.` keys. Nothing under that prefix is part of a backup file.
class SecurityService {
  SecurityService._();

  /// The instance the screens use.
  static final SecurityService instance = SecurityService._();

  static const String _keyPrefix = 'security.';
  static const String _failuresKey = '${_keyPrefix}failed_attempts';
  static const String _lockedUntilKey = '${_keyPrefix}locked_until';

  /// Wrong attempts allowed in a row before sign-in is paused.
  static const int freeAttempts = 5;

  /// How long sign-in is paused after each further wrong attempt: the first
  /// pause, the second, and so on. The last value repeats.
  static const List<Duration> _pauses = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(hours: 1),
  ];

  /// The derivation used. Named here so the values below can be told apart
  /// from a different derivation if it is ever changed.
  static const String algorithm = 'pbkdf2-hmac-sha256';

  /// How many times the derivation is repeated for the built-in credential.
  static const int iterations = 120000;

  static const int _keyBytes = 32;

  // The built-in credential: salt and derived key, base64. To change the
  // password, derive a new key with the same algorithm, [iterations] and a new
  // random salt, and replace these two values.
  static const String _builtInSalt = 'muSMwKmcWgGlbVzucA92Eg==';
  static const String _builtInHash =
      'g4AHo6CN4I42X0v7SURakINI+gzcpirHKUCX44goQAE=';

  /// The credential the app ships with.
  static final SecurityCredential builtIn = SecurityCredential(
    iterations: iterations,
    salt: base64Decode(_builtInSalt),
    hash: base64Decode(_builtInHash),
  );

  /// Credential used instead of [builtIn] while tests run, so a test can sign
  /// in with a cheap derivation instead of waiting for [iterations] rounds.
  /// The app itself never sets it.
  @visibleForTesting
  static SecurityCredential? debugCredential;

  static SecurityCredential get _credential => debugCredential ?? builtIn;

  /// Whether [password] is the security password.
  ///
  /// Throws [SignInLockedException] while sign-in is paused after too many
  /// wrong attempts.
  Future<bool> signIn({required String password}) async {
    final wait = await lockoutRemaining();
    if (wait > Duration.zero) throw SignInLockedException(wait);

    final credential = _credential;
    final derived = await _derive(
      password,
      credential.salt,
      credential.iterations,
    );
    final accepted = _sameBytes(derived, credential.hash);
    if (accepted) {
      await _clearFailures();
    } else {
      await _recordFailure();
    }
    return accepted;
  }

  /// How long sign-in is still paused, or [Duration.zero] when it is open. The
  /// count of wrong attempts and the end of the pause are saved, so closing and
  /// reopening the app does not reset them.
  Future<Duration> lockoutRemaining() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      AppDatabase.metaTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_lockedUntilKey],
    );
    if (rows.isEmpty) return Duration.zero;
    final until = DateTime.tryParse(rows.first['value'] as String? ?? '');
    if (until == null) return Duration.zero;
    final left = until.difference(DateTime.now().toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> _recordFailure() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      AppDatabase.metaTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_failuresKey],
    );
    final before = rows.isEmpty
        ? 0
        : int.tryParse(rows.first['value'] as String? ?? '') ?? 0;
    final failures = before + 1;
    await db.insert(AppDatabase.metaTable, {
      'key': _failuresKey,
      'value': '$failures',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (failures >= freeAttempts) {
      final step = min(failures - freeAttempts, _pauses.length - 1);
      final until = DateTime.now().toUtc().add(_pauses[step]);
      await db.insert(AppDatabase.metaTable, {
        'key': _lockedUntilKey,
        'value': until.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _clearFailures() async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      AppDatabase.metaTable,
      where: 'key IN (?, ?)',
      whereArgs: [_failuresKey, _lockedUntilKey],
    );
  }

  /// Derives the key for [password], on a background isolate so the spinner on
  /// the sign-in screen keeps moving while it works.
  Future<Uint8List> _derive(String password, Uint8List salt, int iterations) =>
      compute(_deriveKeyTask, <Object?>[
        utf8.encode(password),
        salt,
        iterations,
        _keyBytes,
      ]);
}

/// Compares two keys without giving away, through how long the comparison
/// takes, how many leading bytes were right.
bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var index = 0; index < a.length; index++) {
    difference |= a[index] ^ b[index];
  }
  return difference == 0;
}

/// The isolate entry point: `[passwordBytes, salt, iterations, keyBytes]`.
Uint8List _deriveKeyTask(List<Object?> request) => deriveKey(
  password: request[0] as Uint8List,
  salt: request[1] as Uint8List,
  iterations: request[2] as int,
  keyBytes: request[3] as int,
);

/// PBKDF2-HMAC-SHA256 (RFC 8018).
///
/// Each block of the key is the XOR of [iterations] rounds of HMAC over the
/// salt and the block number, which is what turns a short password into a key
/// that is expensive to guess: every attempt costs this whole loop.
@visibleForTesting
Uint8List deriveKey({
  required Uint8List password,
  required Uint8List salt,
  required int iterations,
  required int keyBytes,
}) {
  const int digestSize = 32; // SHA-256
  final hmac = Hmac(sha256, password);
  final blocks = (keyBytes + digestSize - 1) ~/ digestSize;
  final output = Uint8List(blocks * digestSize);

  for (var block = 1; block <= blocks; block++) {
    final seed = Uint8List(salt.length + 4)
      ..setRange(0, salt.length, salt)
      ..[salt.length] = (block >> 24) & 0xff
      ..[salt.length + 1] = (block >> 16) & 0xff
      ..[salt.length + 2] = (block >> 8) & 0xff
      ..[salt.length + 3] = block & 0xff;

    var bytes = hmac.convert(seed).bytes;
    final accumulated = Uint8List.fromList(bytes);
    for (var round = 1; round < iterations; round++) {
      bytes = hmac.convert(bytes).bytes;
      for (var index = 0; index < digestSize; index++) {
        accumulated[index] ^= bytes[index];
      }
    }
    output.setRange((block - 1) * digestSize, block * digestSize, accumulated);
  }

  return Uint8List.sublistView(output, 0, keyBytes);
}
