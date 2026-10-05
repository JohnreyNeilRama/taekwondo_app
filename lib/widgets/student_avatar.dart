import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/student.dart';
import '../theme/app_theme.dart';

/// The saved 1 x 1 ID picture of a student, shown wherever that student is
/// listed: the Students registry, the Promotion and Achievement lists, the
/// student pickers, the forms and the detail headers.
///
/// The picture is read from the student own row (`photo_base64`, the compact
/// copy the storage layer keeps for exactly this), so one uploaded photo is the
/// avatar of that student on every page and is still there after a restart -
/// there is no second place a picture could be kept.
///
/// A student without a picture keeps the initials the screens have always
/// drawn, inside exactly the same box, so the layout of the lists does not
/// change and a missing or corrupt photo can never break a page.
class StudentAvatar extends StatefulWidget {
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
  State<StudentAvatar> createState() => _StudentAvatarState();
}

class _StudentAvatarState extends State<StudentAvatar> {
  /// The decoded picture of the student on screen, or null while they have
  /// none.
  ///
  /// It is decoded once here rather than inside `build`. Decoding in `build`
  /// handed the widget a brand-new `Uint8List` on every frame, and since the
  /// image cache is keyed by the identity of those bytes, that was a cache miss
  /// every time: the picture was re-decoded from scratch as the lists scrolled
  /// or as anything on the screen changed.
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = widget.student?.photoBytes;
  }

  @override
  void didUpdateWidget(StudentAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.student?.id != widget.student?.id ||
        oldWidget.student?.photoBase64 != widget.student?.photoBase64;
    // Only a different student, or a newly saved picture for the same one,
    // costs a decode.
    if (changed) _bytes = widget.student?.photoBytes;
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final fallback = _initials();
    return Container(
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        shape: widget.shape,
        borderRadius: widget.shape == BoxShape.circle
            ? null
            : BorderRadius.circular(widget.borderRadius),
      ),
      child: bytes == null
          ? fallback
          : Image.memory(
              bytes,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              // Keeps the previous frame on screen while a newly saved picture
              // is decoded, so replacing a photo never flashes the initials.
              gaplessPlayback: true,
              // The picture is decoded at the size it is actually drawn at, so
              // a large saved photo never sits in the image cache at full
              // resolution.
              cacheWidth: (widget.size *
                      MediaQuery.devicePixelRatioOf(context))
                  .round(),
              errorBuilder: (context, error, stackTrace) => fallback,
            ),
    );
  }

  /// The initials of the student, or `?` when there is none to show.
  Widget _initials() => Text(
    widget.student?.initials ?? '?',
    style: TextStyle(
      fontSize: widget.initialsFontSize,
      fontWeight: FontWeight.w700,
      color: widget.initialsColor,
    ),
  );
}



