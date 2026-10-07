import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_dark.dart';
import 'registry_header.dart';

/// The rounded-top sheet every page's content sits on, laid over the header.
/// On a tablet or a computer the content keeps a phone-like reading width
/// instead of stretching edge to edge.
class AppSheet extends StatelessWidget {
  const AppSheet({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // What shows in the two corners the sheet's rounded top cuts away.
      color: AppDark.headerBottom,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: ColoredBox(
          color: AppDark.background,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A full page opened from another one: the [RegistryHeader] with a Back
/// button, the content on the rounded sheet, and an optional [bottom] bar for
/// the page's actions (see [AppActionBar]).
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.onBack,
    this.actions = const [],
    this.bottom,
  });

  final String title;
  final String? subtitle;

  /// What Back does. Defaults to closing the page.
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget child;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppDark.navBar,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppDark.headerBottom,
        body: Column(
          children: [
            RegistryHeader(
              title: title,
              subtitle: subtitle,
              onBack: onBack ?? () => Navigator.of(context).maybePop(),
              actions: actions,
            ),
            Expanded(child: AppSheet(child: child)),
            ?bottom,
          ],
        ),
      ),
    );
  }
}

/// The bar at the foot of a page that holds its actions (Save, Cancel, Edit).
/// It keeps clear of the system navigation area.
class AppActionBar extends StatelessWidget {
  const AppActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppDark.navBar,
        border: const Border(top: BorderSide(color: AppDark.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A page's own title block: the big title, a quiet line under it, and an
/// optional [trailing] widget (the main action) beside it when the width allows
/// and underneath, full width, when it does not.
class PageIntro extends StatelessWidget {
  const PageIntro({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: AppDark.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppDark.textSecondary,
                ),
              ),
            ],
          ],
        );
        final action = trailing;
        if (action == null) return text;
        if (constraints.maxWidth >= 360) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: text),
              const SizedBox(width: 12),
              action,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            text,
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: action),
          ],
        );
      },
    );
  }
}

/// A small spaced-out label that opens a group of fields or rows.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: AppDark.rose,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// The crimson gradient button with a soft red glow, for the one main action of
/// a page. [expand] makes it fill the width.
class CrimsonButton extends StatelessWidget {
  const CrimsonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.busy = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;

  /// Shows a small spinner in place of the icon, for an action that is running.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled ? AppDark.crimsonGradient : null,
        color: enabled ? null : AppDark.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        boxShadow: enabled ? AppDark.crimsonGlow : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy) ...[
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: enabled ? Colors.white : AppDark.crimson,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ] else if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 21),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enabled
                            ? Colors.white
                            : AppDark.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded-square plate holding one icon, the way list rows and cards mark
/// what they are about.
class IconPlate extends StatelessWidget {
  const IconPlate({
    super.key,
    required this.icon,
    this.size = 42,
    this.color = AppDark.rose,
    this.background = AppDark.surfaceHigh,
  });

  final IconData icon;
  final double size;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: AppDark.border),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// Keeps a bar (usually the search card) pinned under the page's title block
/// while the list scrolls beneath it.
class PinnedBarDelegate extends SliverPersistentHeaderDelegate {
  PinnedBarDelegate({required this.child, this.extent = 72});

  final Widget child;

  /// Height of the pinned area: the bar plus the space above and below it.
  final double extent;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppDark.background,
        // A hairline appears once cards are sliding underneath.
        border: Border(
          bottom: BorderSide(
            color: overlapsContent ? AppDark.border : Colors.transparent,
          ),
        ),
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant PinnedBarDelegate oldDelegate) => true;
}

/// A dark card: the surface every grouped block of content sits on. [accent]
/// draws the thin crimson line down the left edge the registry cards have.
class DarkCard extends StatelessWidget {
  const DarkCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.accent,
    this.radius = 20,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Colour of the left edge line, or null for none.
  final Color? accent;
  final double radius;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: AppDark.cardShadow,
        ),
        child: Material(
          color: AppDark.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: const BorderSide(color: AppDark.border),
          ),
          child: InkWell(
            onTap: onTap,
            splashColor: AppDark.crimson.withValues(alpha: 0.12),
            highlightColor: AppDark.crimson.withValues(alpha: 0.06),
            child: Stack(
              children: [
                if (accent != null)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 4,
                    child: ColoredBox(color: accent!),
                  ),
                Padding(
                  padding: accent == null
                      ? padding
                      : padding.add(const EdgeInsets.only(left: 4)),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
