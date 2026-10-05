import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tkd_app/models/student.dart';
import 'package:tkd_app/services/app_database.dart';
import 'package:tkd_app/services/backup_service.dart';
import 'package:tkd_app/services/student_storage.dart';

/// The reminder that nudges the owner to export, so recovery does not depend on
/// remembering on their own.
void main() {
  final backup = BackupService();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.debugReset();
    AppDatabase.debugOverridePath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await AppDatabase.debugReset();
  });

  test('an empty registry never reminds', () async {
    expect(await backup.reminderDue(), isFalse);
  });

  test('records that were never backed up remind, and an export clears it', () async {
    await StudentStorage().insert(const Student(name: 'Ana Cruz'));
    expect(await backup.reminderDue(), isTrue);

    await backup.markExported();

    expect(await backup.lastExportAt(), isNotNull);
    expect(await backup.reminderDue(), isFalse);
  });

  test('a backup older than the reminder age reminds again', () async {
    await StudentStorage().insert(const Student(name: 'Ana Cruz'));
    final now = DateTime.utc(2026, 1, 1);
    await backup.markExported(now: now);
    expect(await backup.reminderDue(now: now), isFalse);

    final later = now.add(BackupService.reminderAfter + const Duration(days: 1));
    expect(await backup.reminderDue(now: later), isTrue);
  });
}
