import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/app_database.dart';
import '../services/backup_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_header.dart';
import '../widgets/empty_state_card.dart';

/// Backup / transfer hub: export the registry to a file and import one back.
///
/// The counts at the top are read from the database, and the file is the whole
/// registry (students, pictures, promotion records and achievements) in one
/// JSON document. Importing only ever adds records; it never changes or deletes
/// what is already on the device.
class DataTransferScreen extends StatefulWidget {
  const DataTransferScreen({super.key, this.visits = 0});

  /// Bumped by the home shell on every destination change, so the counts are
  /// re-read each time the owner comes back to this page.
  final int visits;

  @override
  State<DataTransferScreen> createState() => _DataTransferScreenState();
}

class _DataTransferScreenState extends State<DataTransferScreen> {
  final BackupService _backup = BackupService();
  BackupCounts? _counts;

  /// When this device last saved a backup, or null when it never has.
  DateTime? _lastExport;

  /// Whether the owner should be reminded to export (no backup yet, or the
  /// last one is older than [BackupService.reminderAfter]).
  bool _backupDue = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  @override
  void didUpdateWidget(DataTransferScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visits != widget.visits) _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final counts = await _backup.counts();
      final last = await _backup.lastExportAt();
      final due = await _backup.reminderDue();
      if (!mounted) return;
      setState(() {
        _counts = counts;
        _lastExport = last;
        _backupDue = due;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _counts = null);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _backup.exportBytes();
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save backup',
        fileName: BackupService.suggestedFileName(),
        bytes: bytes,
      );
      if (saved == null) return; // The owner closed the dialog.
      await _writeOnDesktop(saved, bytes);
      // A backup has just been saved, so the reminder starts counting again
      // from now instead of nagging on the next visit.
      await _backup.markExported();
      await _loadCounts();
      _toast('Backup saved');
    } catch (_) {
      _toast('Could not save the backup. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The save dialog of the phone writes the file itself. On a computer it only
  /// hands back the chosen path, so the file is written here when it is not
  /// already there.
  Future<void> _writeOnDesktop(Uri saved, Uint8List bytes) async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
    final path = saved.scheme == 'file' ? saved.toFilePath() : saved.toString();
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() != bytes.length) {
      await file.writeAsBytes(bytes);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (files.isEmpty || !mounted) return;
      final file = files.first;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Add these records?'),
          content: Text(
            'The records in "${file.name}" will be added to this device. '
            'Records that are already here are not changed or deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      setState(() => _busy = true);
      final bytes = await file.readAsBytes();
      final result = await _backup.importBytes(bytes);
      await _loadCounts();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Import finished'),
          content: Text(_summary(result)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on BackupFormatException catch (error) {
      _toast(error.message);
    } catch (_) {
      _toast('Could not import the backup. Nothing was changed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Runs SQLite's own consistency check on the saved file and tells the owner
  /// the result, so a damaged database is found before records go missing.
  Future<void> _checkDatabase() async {
    if (_busy) return;
    setState(() => _busy = true);
    // True: healthy. False: the file reported a problem. Null: the check
    // itself could not run.
    bool? healthy;
    try {
      healthy = await AppDatabase.instance.isHealthy();
    } catch (_) {
      healthy = null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;

    final String title;
    final String message;
    if (healthy == true) {
      title = 'Database is healthy';
      message = 'No problems were found in the saved file on this device.';
    } else if (healthy == false) {
      title = 'A problem was found';
      message =
          'The saved file reports an inconsistency. Export a backup now and '
          'keep it somewhere safe, then restart the app. If this message '
          'comes back, keep that backup and get help before adding more '
          'records.';
    } else {
      title = 'Could not run the check';
      message =
          'The check could not be completed. Please try again. If it keeps '
          'failing, export a backup while you still can.';
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static String _plural(int count, String one, [String? many]) =>
      '$count ${count == 1 ? one : (many ?? '${one}s')}';

  static String _summary(ImportResult result) {
    final lines = <String>[];
    if (result.addedNothing) {
      lines.add(
        result.matchedStudents > 0
            ? 'Everything in this backup is already on this device. '
                  'Nothing was added.'
            : 'The backup held nothing new to add.',
      );
    } else {
      final added = [
        if (result.addedStudents > 0) _plural(result.addedStudents, 'student'),
        if (result.addedPromotions > 0)
          _plural(result.addedPromotions, 'promotion record'),
        if (result.addedAchievements > 0)
          _plural(result.addedAchievements, 'achievement'),
      ];
      lines.add('Added ${added.join(', ')}.');
      if (result.matchedStudents > 0) {
        lines.add(
          '${_plural(result.matchedStudents, 'student was', 'students were')} '
          'already on this device.',
        );
      }
    }
    if (result.skipped > 0) {
      lines.add(
        '${_plural(result.skipped, 'row')} in the file could not be used and '
        '${result.skipped == 1 ? 'was' : 'were'} skipped.',
      );
    }
    return lines.join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const BrandHeader(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Import / Export Data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              const Text(
                'Back up your registry or move it to a new device',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              _BackupStatusCard(due: _backupDue, lastExport: _lastExport),
              const SizedBox(height: 16),
              _StorageSummary(counts: _counts),
              const SizedBox(height: 16),
              _ActionCard(
                icon: Icons.file_download_outlined,
                title: 'Export data',
                message:
                    'Save a copy of all student records to a file you can '
                    'keep or move to another device.',
                buttonLabel: 'Export backup',
                onPressed: _busy ? null : _export,
              ),
              _ActionCard(
                icon: Icons.file_upload_outlined,
                title: 'Import data',
                message:
                    'Load records from a backup file. Imported records are '
                    'merged with the ones already on this device.',
                buttonLabel: 'Import backup',
                tone: AppColors.red,
                onPressed: _busy ? null : _import,
              ),
              _ActionCard(
                icon: Icons.health_and_safety_outlined,
                title: 'Check database',
                message:
                    'Checks that the saved file on this device is intact. '
                    'Worth running now and then, or if the app ever behaves '
                    'strangely.',
                buttonLabel: 'Check now',
                buttonIcon: Icons.fact_check_outlined,
                onPressed: _busy ? null : _checkDatabase,
              ),
              const _TransferredList(),
              const NoticeCard(
                icon: Icons.warning_amber_outlined,
                message:
                    'Importing only adds records: nothing already on this '
                    'device is changed or deleted. Export often and keep the '
                    'file somewhere safe, such as your cloud storage or an '
                    'email to yourself.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Explains exactly which data a backup carries.
class _TransferredList extends StatelessWidget {
  const _TransferredList();

  @override
  Widget build(BuildContext context) {
    return const SectionCard(
      icon: Icons.inventory_2_outlined,
      title: 'What gets transferred',
      subtitle: 'Included in every backup',
      showDivider: false,
      child: Column(
        children: [
          _TransferRow(
            icon: Icons.groups_outlined,
            label: 'Student records',
            detail: 'Full details, contacts and guardians',
          ),
          _TransferRow(
            icon: Icons.image_outlined,
            label: 'ID pictures',
            detail: '1x1 photos attached to each student',
          ),
          _TransferRow(
            icon: Icons.assignment_outlined,
            label: 'Promotion records',
            detail: 'Test results and grade progression',
          ),
          _TransferRow(
            icon: Icons.military_tech_outlined,
            label: 'Achievements',
            detail: 'Awards, titles and milestones',
          ),
        ],
      ),
    );
  }
}

/// One number in the storage summary strip.
class _StorageStat extends StatelessWidget {
  const _StorageStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }
}

/// Headline numbers describing what is currently stored on this device.
class _StorageSummary extends StatelessWidget {
  const _StorageSummary({required this.counts});

  /// Null while the numbers are being read, or when they could not be.
  final BackupCounts? counts;

  @override
  Widget build(BuildContext context) {
    String show(int? value) => value == null ? '–' : '$value';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'On this device',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StorageStat(
                  value: show(counts?.students),
                  label: 'Students',
                ),
              ),
              Expanded(
                child: _StorageStat(
                  value: show(counts?.photos),
                  label: 'Photos',
                ),
              ),
              Expanded(
                child: _StorageStat(
                  value: show(counts?.promotions),
                  label: 'Tests',
                ),
              ),
              Expanded(
                child: _StorageStat(
                  value: show(counts?.achievements),
                  label: 'Awards',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single row in the "what gets transferred" list.
class _TransferRow extends StatelessWidget {
  const _TransferRow({
    required this.icon,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.iconCircle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: AppColors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The reminder at the top of the Data page: how fresh the last backup is, and
/// a clear nudge to export when there is none or it is getting old.
///
/// There is no automatic copy: recovering this device depends on the owner
/// exporting a file and keeping it somewhere safe, so this card's one job is to
/// say that plainly — in red — before it is too late.
class _BackupStatusCard extends StatelessWidget {
  const _BackupStatusCard({required this.due, required this.lastExport});

  /// Whether a backup is due (never exported, or older than the reminder age).
  final bool due;

  /// When the last backup was saved, or null when there has never been one.
  final DateTime? lastExport;

  /// "never", "today", "yesterday" or "N days ago".
  static String _ago(DateTime? when, DateTime now) {
    if (when == null) return 'never';
    final days = now.difference(when).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    return '$days days ago';
  }

  @override
  Widget build(BuildContext context) {
    final ago = _ago(lastExport, DateTime.now());
    final tone = due ? AppColors.red : AppColors.black;
    final icon = due ? Icons.warning_amber_outlined : Icons.verified_outlined;
    final title = due ? 'Back up your records' : 'Your backup is up to date';
    final message = due
        ? (lastExport == null
              ? 'You have not saved a backup yet. Export one now and keep the '
                    'file somewhere safe: without it, a lost or damaged phone '
                    'cannot be recovered.'
              : 'Your last backup was $ago. Export a fresh one and keep it '
                    'somewhere safe so recent changes are not lost.')
        : 'Last backup: $ago.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: due ? AppColors.redTint : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: due ? AppColors.red : AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: due ? Colors.white : AppColors.iconCircle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: tone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: due ? AppColors.red : AppColors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Large action card used for both the Export and Import choices.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
    this.tone = AppColors.black,
    this.buttonIcon,
  });

  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;

  /// Null disables the button, which is how a running export or import keeps a
  /// second tap from starting another one.
  final VoidCallback? onPressed;

  /// Button / icon colour; the import action uses the brand red so the two
  /// directions are instantly distinguishable.
  final Color tone;

  /// Icon on the button. When null, the export / import arrow that matches
  /// [tone] is used.
  final IconData? buttonIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone == AppColors.red
                      ? AppColors.redTint
                      : AppColors.iconCircle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: tone),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPressed,
              style: FilledButton.styleFrom(backgroundColor: tone),
              icon: Icon(
                buttonIcon ??
                    (tone == AppColors.red
                        ? Icons.file_upload_outlined
                        : Icons.file_download_outlined),
                size: 18,
              ),
              label: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
