import 'student_uid.dart';

/// What a student's QR code says, and how a scanned code is read back.
///
/// The code carries the student's permanent `uid` and nothing else, so it holds
/// no personal details and never goes out of date: renaming a student or
/// renumbering the registry does not change it, and a backup imported onto
/// another phone recognises the same code.
class StudentQr {
  const StudentQr._();

  /// Marks a code as one of this app's, so any other QR code a phone camera
  /// happens to see (a poster, a menu) is ignored instead of being looked up.
  static const String prefix = 'TKD:';

  /// The text written into the QR code of the student with this [uid].
  static String encode(String uid) => '$prefix$uid';

  /// The student uid inside a scanned [text], or null when the text is not one
  /// of this app's student codes.
  static String? decode(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith(prefix)) return null;
    final uid = trimmed.substring(prefix.length).trim().toLowerCase();
    return isStudentUid(uid) ? uid : null;
  }
}
