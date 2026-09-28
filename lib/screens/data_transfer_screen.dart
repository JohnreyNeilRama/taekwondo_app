import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/brand_header.dart';
import '../widgets/empty_state_card.dart';

/// Backup / transfer hub: move the registry between devices.
/// UI only for now — the export and import buttons explain what they will do
/// once file handling is connected.
class DataTransferScreen extends StatelessWidget {
  const DataTransferScreen({super.key});

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
              const NoticeCard(
                icon: Icons.info_outline,
                message:
                    'Preview layout only. Export and import will be enabled '
                    'once file handling is connected.',
              ),
              const SizedBox(height: 16),
              const _StorageSummary(),
              const SizedBox(height: 16),
              _ActionCard(
                icon: Icons.file_download_outlined,
                title: 'Export data',
                message:
                    'Save a copy of all student records to a file you can '
                    'keep or move to another device.',
                buttonLabel: 'Export backup',
                onPressed: () => _notImplemented(context, 'Export'),
              ),
              _ActionCard(
                icon: Icons.file_upload_outlined,
                title: 'Import data',
                message:
                    'Load records from a backup file. Imported records are '
                    'merged with the ones already on this device.',
                buttonLabel: 'Import backup',
                tone: AppColors.red,
                onPressed: () => _notImplemented(context, 'Import'),
              ),
              const _TransferredList(),
              const NoticeCard(
                icon: Icons.warning_amber_outlined,
                message:
                    'Importing adds records to this device. Export often so '
                    'you always have a recent copy of your data.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _notImplemented(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action is not available yet.'),
        behavior: SnackBarBehavior.floating,
      ),
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
  const _StorageSummary();

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'On this device',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Preview',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: _StorageStat(value: '4', label: 'Students'),
              ),
              Expanded(
                child: _StorageStat(value: '4', label: 'Photos'),
              ),
              Expanded(
                child: _StorageStat(value: '3', label: 'Tests'),
              ),
              Expanded(
                child: _StorageStat(value: '4', label: 'Awards'),
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

/// Large action card used for both the Export and Import choices.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
    this.tone = AppColors.black,
  });

  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  /// Button / icon colour; the import action uses the brand red so the two
  /// directions are instantly distinguishable.
  final Color tone;

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
                tone == AppColors.red
                    ? Icons.file_upload_outlined
                    : Icons.file_download_outlined,
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
