import 'package:flutter/material.dart';

import '../models/student.dart';
import '../theme/app_theme.dart';

/// The saved 1 x 1 ID picture of a student, shown wherever that student is
/// listed: the Students registry, the Promotion and Achievement lists, the
/// student pickers, the forms and the detail headers.
///
/// The picture is read from the student own row (`photo_base64`), so one
/// uploaded photo is the avatar of that student on every page and is still
/// there after a restart - there is no second place a picture could be kept.
///
/// A student without a picture keeps the initials the screens have always
/// drawn, inside exactly the same box, so the layout of the lists does not
/// change and a missing or corrupt photo can never break a page.
class StudentAvatar extends StatelessWidget {
  const StudentAvatar({
    super.key,
    required this.student,
    required this.size,
    this.borderRadius = 14,
    this.initialsFontSize = 16,
    this.backgroundColor = AppColors.iconCircle,
    this.initialsColor = AppColors.muted,
    this.shape = BoxShape.rectangle,
  });

  /// The registry entry whose picture is shown. Null while a student still has
  /// to be chosen, which draws the `?` fallback.
  final Student? student;

  /// Width and height of the square (or circle) the picture is drawn in.
  final double size;

  /// Corner radius of the box. Ignored when [shape] is [BoxShape.circle].
  final double borderRadius;

  /// Size of the initials drawn when the student has no picture.
  final double initialsFontSize;

  final Color backgroundColor;
  final Color initialsColor;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final bytes = student?.photoBytes;
    final fallback = _initials();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(borderRadius),
      ),
      child: bytes == null
          ? fallback
          : Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // Keeps the previous frame on screen while a newly saved picture
              // is decoded, so replacing a photo never flashes the initials.
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => fallback,
            ),
    );
  }

  /// The initials of the student, or `?` when there is none to show.
  Widget _initials() => Text(
    student?.initials ?? '?',
    style: TextStyle(
      fontSize: initialsFontSize,
      fontWeight: FontWeight.w700,
      color: initialsColor,
    ),
  );
}