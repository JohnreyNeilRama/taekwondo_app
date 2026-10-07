import 'package:flutter/material.dart';

import '../theme/app_dark.dart';

/// Dark rounded card used to group related content on a screen: a navy surface,
/// 20px corners, a hairline border and a soft shadow, with an optional header
/// row (icon plate, title, subtitle, trailing action) and a divider.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.icon,
    this.title,
    this.subtitle,
    this.trailing,
    this.showDivider = true,
    required this.child,
  });

  final IconData? icon;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final bool showDivider;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppDark.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDark.border),
        boxShadow: AppDark.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasHeader) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppDark.surfaceHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppDark.border),
                      ),
                      child: Icon(icon, size: 19, color: AppDark.rose),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppDark.textPrimary,
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppDark.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
            if (showDivider)
              const Divider(height: 1, thickness: 1, color: AppDark.border),
          ],
          child,
        ],
      ),
    );
  }
}

/// Small rounded chip used for statuses, registry numbers and filter
/// selections.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.emphasized = false,
  });

  final String label;
  final IconData? icon;

  /// Renders the chip in the crimson accent used for selected filters and
  /// registry numbers instead of the neutral plate.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final color = emphasized ? AppDark.rose : AppDark.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: emphasized
            ? AppDark.crimson.withValues(alpha: 0.16)
            : AppDark.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: emphasized
              ? AppDark.crimson.withValues(alpha: 0.35)
              : AppDark.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft crimson info strip used to flag important information without pulling
/// attention away from the main content.
class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppDark.crimson.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDark.crimson.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppDark.rose),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppDark.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark rounded card with an icon disc, a title, a message and an optional
/// full-width action button.
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
      decoration: BoxDecoration(
        color: AppDark.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDark.border),
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppDark.surfaceHigh,
              shape: BoxShape.circle,
              border: Border.all(color: AppDark.border),
            ),
            child: Icon(icon, size: 38, color: AppDark.rose),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppDark.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppDark.textSecondary,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
