import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/student.dart';
import '../services/student_qr.dart';
import '../theme/app_theme.dart';
import 'student_avatar.dart';

/// The printable ID card a student receives: club header, photo, name, registry
/// number and the attendance QR code.
///
/// It is drawn at a fixed logical size ([width] x [height], the 85.6 x 54 mm
/// ratio of a bank-card sized ID) so the picture that is shared or printed
/// looks the same on every phone. Wrap it in a `RepaintBoundary` to turn it
/// into an image.
class StudentIdCard extends StatelessWidget {
  const StudentIdCard({super.key, required this.student});

  final Student student;

  static const double width = 340;
  static const double height = 214;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.black, width: 1.2),
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
      color: AppColors.black,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.red,
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
          const Text(
            'TKD Records',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          const Text(
            'STUDENT ID',
            style: TextStyle(
              color: Color(0xFFD1D5DB),
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
        StudentAvatar(student: student, size: 64, borderRadius: 10),
        const SizedBox(height: 10),
        Text(
          student.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
        if (student.studentNo.isNotEmpty)
          Text(
            'No. ${student.studentNo}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
      ],
    );
  }
}
