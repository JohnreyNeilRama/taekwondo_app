import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/student.dart';
import '../services/student_card_export.dart';
import '../services/student_qr.dart';
import '../services/student_uid.dart';
import '../theme/app_theme.dart';
import '../widgets/student_avatar.dart';
import '../widgets/student_id_card.dart';

/// A student's QR code, drawn large enough to be scanned from another phone or
/// from a printout.
///
/// Shown automatically right after a student is added ([justSaved]) and from the
/// QR button on the student's details page. The code carries only the student's
/// permanent identity, so it stays valid when the name or number changes.
class StudentQrScreen extends StatefulWidget {
  const StudentQrScreen({
    super.key,
    required this.student,
    this.justSaved = false,
  });

  final Student student;

  /// True when the screen opens straight after the student was added: the title
  /// and the note above the code say so.
  final bool justSaved;

  @override
  State<StudentQrScreen> createState() => _StudentQrScreenState();
}

class _StudentQrScreenState extends State<StudentQrScreen> {
  /// Marks the ID card that is turned into an image for sharing and printing.
  final GlobalKey _cardKey = GlobalKey();

  /// True while an export is running, so a double tap cannot start two.
  bool _busy = false;

  Student get student => widget.student;
  bool get justSaved => widget.justSaved;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (justSaved) ...[_savedNote(), const SizedBox(height: 16)],
                _codeCard(),
                const SizedBox(height: 16),
                _shareCard(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildDoneBar(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.black,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      justSaved ? 'Student saved' : 'Student QR code',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Used to record attendance',
                      style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _savedNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.redTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.red, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'The student was added and their QR code is ready. Share or '
              'print the ID card below so the student has it: scanning the '
              'code records attendance.',
              style: TextStyle(fontSize: 13, color: AppColors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _codeCard() {
    final hasCode = isStudentUid(student.uid);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              StudentAvatar(
                student: student,
                size: 48,
                shape: BoxShape.circle,
                initialsFontSize: 16,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                    if (student.studentNo.isNotEmpty)
                      Text(
                        student.studentNo,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (hasCode)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: QrImageView(
                data: StudentQr.encode(student.uid),
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'This student has no QR identity yet. Close and reopen the '
                'app, then try again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'The code never changes, even if the name or the registry number '
            'does, so a printed copy stays valid.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  /// The ID card with the actions that hand it to the student: share it as a
  /// picture, save it to the device, or print a sheet of cards.
  Widget _shareCard() {
    if (!isStudentUid(student.uid)) return const SizedBox.shrink();
    final outlined = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      foregroundColor: AppColors.black,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ID card',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Give the student their card as a picture or a printed sheet.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          // The card keeps its fixed size and is scaled down to fit narrow
          // screens; the exported picture is always the full-size card.
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: RepaintBoundary(
                key: _cardKey,
                child: StudentIdCard(student: student),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _share,
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('Share'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: outlined,
                  onPressed: _busy ? null : _saveImage,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Save image'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: outlined,
                  onPressed: _busy ? null : _printSheet,
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Print sheet'),
                ),
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 3),
          ],
        ],
      ),
    );
  }

  Future<void> _share() => _export(
    (png) async {
      await StudentCardExport.share(png, student.name);
      return null;
    },
  );

  Future<void> _saveImage() =>
      _export((png) => StudentCardExport.saveImage(png, student.name));

  Future<void> _printSheet() => _export(
    (png) async {
      await StudentCardExport.printSheet(png, student.name);
      return null;
    },
  );

  /// Renders the card once, runs [action] on the picture, and reports the
  /// result. Any failure becomes a short message instead of a crash.
  Future<void> _export(Future<String?> Function(Uint8List png) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final png = await StudentCardExport.capture(_cardKey);
      final message = await action(png);
      if (message != null) _toast(message);
    } catch (error) {
      debugPrint('Student card export failed: $error');
      _toast('Could not complete that. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildDoneBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Done'),
            ),
          ),
        ),
      ),
    );
  }
}
