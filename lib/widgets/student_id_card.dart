import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/student.dart';
import '../services/student_qr.dart';
import '../theme/app_dark.dart';
import 'student_avatar.dart';

/// The printable ID card a student receives: club header, photo, name, registry
/// number and the attendance QR code.
///
/// It is drawn at a fixed logical size ([width] x [height], the 85.6 x 54 mm
/// ratio of a bank-card sized ID) so the picture that is shared or printed
/// looks the same on every phone. Wrap it in a `RepaintBoundary` to turn it
/// into an image.
///
/// The card is a physical object, not a page of the app, so it keeps its own
/// light colours whatever the app theme is: dark ink on white paper is what
/// prints well and what a QR scanner reads best.
class StudentIdCard extends StatelessWidget {
  const StudentIdCard({super.key, required this.student});

  final Student student;

  static const double width = 340;
  static const double height = 214;

  static const Color _paper = Colors.white;
  static const Color _ink = Color(0xFF0F1626);
  static const Color _quiet = Color(0xFF5B6478);
  static const Color _plate = Color(0xFFEEF0F4);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ink, width: 1.2),
      ),
      child: Column(
        children: [
          _header(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(child: _identity()),
                  const SizedBox(width: 10),
                  QrImageView(
                    data: StudentQr.encode(student.uid),
                    version: QrVersions.auto,
                    size: 112,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppDark.headerTop, AppDark.headerBottom],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppDark.crimsonGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'TKD',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'TKD Records',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'STUDENT ID',
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _identity() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudentAvatar(
          student: student,
          size: 64,
          borderRadius: 10,
          backgroundColor: _plate,
          initialsColor: _quiet,
        ),
        const SizedBox(height: 10),
        Text(
          student.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ],
    );
  }
}
