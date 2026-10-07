import 'package:flutter/material.dart';

import '../theme/app_dark.dart';

/// The dark header of every page: a soft crimson glow in the upper-right corner
/// of a navy gradient, then either the TKD logo (the main pages) or a Back
/// button (pages opened from another one), the [title] and [subtitle], and
/// [actions] at the right.
///
/// With no arguments it is the registry header the main pages share: the logo,
/// "TKD Records" and "Student Registry".
class RegistryHeader extends StatelessWidget {
  const RegistryHeader({
    super.key,
    this.title = 'TKD Records',
    this.subtitle = 'Student Registry',
    this.onBack,
    this.actions = const [],
  });

  final String title;

  /// The line under the title. Pass null for a header with only a title.
  final String? subtitle;

  /// When set, a Back button replaces the logo and calls this.
  final VoidCallback? onBack;

  /// Buttons shown at the right end, e.g. a [HeaderIconButton].
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final isSubPage = onBack != null;
    return Container(
      // The glow is bigger than the header; it is cut off at the header's edge.
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppDark.headerTop, AppDark.headerBottom],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -50,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppDark.crimson.withValues(alpha: 0.40),
                      AppDark.crimson.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isSubPage ? 12 : 16,
                14,
                12,
                isSubPage ? 18 : 20,
              ),
              child: Row(
                children: [
                  if (isSubPage)
                    HeaderIconButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Back',
                      onPressed: onBack!,
                    )
                  else
                    const _Logo(),
                  SizedBox(width: isSubPage ? 14 : 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppDark.textPrimary,
                            fontSize: isSubPage ? 19 : 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppDark.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  for (final action in actions) ...[
                    const SizedBox(width: 8),
                    action,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The TKD mark: white letters on a crimson rounded square.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppDark.crimsonGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: AppDark.crimsonGlow,
      ),
      // Scales down instead of overflowing when the system text size is large.
      child: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'TKD',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

/// A 46 px rounded-square icon button for the header: a faint white plate with a
/// hairline border, and a ripple when pressed.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;

  /// Null greys the button out.
  final VoidCallback? onPressed;

  /// The icon colour; white by default. A page uses it to show a state, such
  /// as the amber of a cancelled class day.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(
              icon,
              color: onPressed == null
                  ? AppDark.textSecondary.withValues(alpha: 0.5)
                  : (color ?? AppDark.textPrimary),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
