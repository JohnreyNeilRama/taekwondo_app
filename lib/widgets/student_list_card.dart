import 'package:flutter/material.dart';

import '../models/student.dart';
import '../theme/app_dark.dart';
import 'student_avatar.dart';

enum _CardAction { view, edit, qr, trash }

/// One student in the registry list: a dark rounded card with a thin crimson
/// line down its left edge, the saved picture, the name, the nickname and
/// school when there are any, and a three-dot menu holding View details, Edit,
/// QR code and Move to Trash.
///
/// The whole card opens the student's details. The picture (which opens larger)
/// and the menu take their own taps. Nothing on the card shows
/// the registry number or the contact number.
class StudentListCard extends StatelessWidget {
  const StudentListCard({
    super.key,
    required this.student,
    required this.title,
    required this.onView,
    required this.onEdit,
    required this.onShowQr,
    required this.onTrash,
  });

  final Student student;

  /// The name as the registry shows it (family name first).
  final String title;

  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onShowQr;
  final VoidCallback onTrash;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // A small phone gets a smaller picture and tighter padding, so the name
        // keeps room next to the two buttons.
        final compact = constraints.maxWidth < 340;
        final avatarSize = compact ? 52.0 : 64.0;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppDark.cardShadow,
          ),
          child: Material(
            color: AppDark.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppDark.border),
            ),
            child: InkWell(
              onTap: onView,
              splashColor: AppDark.crimson.withValues(alpha: 0.12),
              highlightColor: AppDark.crimson.withValues(alpha: 0.06),
              child: Stack(
                children: [
                  // The accent line: the card's rounded corners clip it.
                  const Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFF0475E), AppDark.crimsonDeep],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(compact ? 14 : 18, 14, 6, 14),
                    child: Row(
                      children: [
                        // The picture opens larger on its own; this inner
                        // gesture claims the tap, so it never also opens the
                        // details.
                        Semantics(
                          button: true,
                          label: 'View photo',
                          child: GestureDetector(
                            onTap: () => showStudentPhoto(
                              context,
                              student: student,
                              title: title,
                            ),
                            child: StudentAvatar(
                              student: student,
                              size: avatarSize,
                              borderRadius: 16,
                              initialsFontSize: compact ? 18 : 22,
                              backgroundColor: AppDark.surfaceHigh,
                              initialsColor: AppDark.textSecondary,
                            ),
                          ),
                        ),
                        SizedBox(width: compact ? 12 : 16),
                        Expanded(child: _details()),
                        const SizedBox(width: 4),
                        _menu(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The name, then the nickname and the school when the student has them. A
  /// student with neither simply gets a shorter card: nothing is made up.
  Widget _details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: AppDark.textPrimary,
          ),
        ),
        if (student.nickname.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '"${student.nickname}"',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: AppDark.rose,
            ),
          ),
        ],
        if (student.schoolName.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.school_outlined,
                size: 15,
                color: AppDark.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  student.schoolName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppDark.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _menu() {
    return PopupMenuButton<_CardAction>(
      tooltip: 'More options',
      // 12 px around the 24 px icon makes the button 48 x 48: a comfortable
      // touch target, since this menu is also the way to Edit.
      padding: const EdgeInsets.all(12),
      color: AppDark.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppDark.border),
      ),
      icon: const Icon(Icons.more_vert, color: AppDark.textSecondary),
      onSelected: (action) {
        switch (action) {
          case _CardAction.view:
            onView();
          case _CardAction.edit:
            onEdit();
          case _CardAction.qr:
            onShowQr();
          case _CardAction.trash:
            onTrash();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _CardAction.view,
          child: _MenuRow(icon: Icons.person_outline, label: 'View details'),
        ),
        PopupMenuItem(
          value: _CardAction.edit,
          child: _MenuRow(icon: Icons.edit_outlined, label: 'Edit'),
        ),
        PopupMenuItem(
          value: _CardAction.qr,
          child: _MenuRow(icon: Icons.qr_code_2, label: 'QR code'),
        ),
        PopupMenuItem(
          value: _CardAction.trash,
          child: _MenuRow(
            icon: Icons.delete_outline,
            label: 'Move to Trash',
            color: AppDark.crimson,
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.color = AppDark.textPrimary,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Shows the student's saved picture larger, centred in a dialog.
///
/// The picture is the one on the student's own row ([Student.photoBytes]); a
/// student who has none opens their initials at the same size, so the tap
/// always does something. Tap outside, or the Close button, to dismiss it.
void showStudentPhoto(
  BuildContext context, {
  required Student student,
  required String title,
}) {
  final bytes = student.photoBytes;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppDark.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppDark.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close, color: AppDark.icon),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: 240,
                    height: 240,
                    child: bytes == null
                        ? StudentAvatar(
                            student: student,
                            size: 240,
                            borderRadius: 18,
                            initialsFontSize: 72,
                            backgroundColor: AppDark.surfaceHigh,
                            initialsColor: AppDark.textSecondary,
                          )
                        : Image.memory(bytes, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppDark.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
