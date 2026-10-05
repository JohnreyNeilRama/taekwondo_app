import 'dart:math';

/// A stable identity for one student that survives every rename, renumbering
/// and move between devices.
///
/// The database's own `students.id` cannot be that identity: it is rewritten
/// when a backup from another device is imported (a student gets a fresh id on
/// the device it is imported into), so it can never tell whether the "Ana
/// Cruz" in a backup file is the same person already saved here. The registry
/// number cannot be it either, because a permanent delete packs the numbers
/// back together, moving everybody after the deleted student up by one.
///
/// So every student carries a [uid]: a random 128-bit value minted once, when
/// the record is created, and never changed afterwards. The Data page writes
/// it into the backup, and importing the same file on any device recognises
/// the same person by it — which is what keeps a restore from adding a second
/// copy of a student after a rename or a renumbering.
class StudentUid {
  const StudentUid._();

  /// [Random.secure] so two devices can never mint the same id by accident.
  static final Random _random = Random.secure();

  /// A new unique id, formatted as a UUID v4 (`8-4-4-4-12` hex digits).
  static String generate() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    // RFC 4122: version 4 in the top nibble of byte 6, variant 10xx in byte 8.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = [
      for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
    ].join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}

/// Whether [value] looks like a [StudentUid] this app minted.
///
/// Used when reading a backup: a file written before uids existed carries an
/// empty value, and anything else that is not a real uid is treated as missing
/// so it can never be trusted as an identity.
bool isStudentUid(String value) =>
    RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
        .hasMatch(value);
