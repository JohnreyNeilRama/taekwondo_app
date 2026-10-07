import 'package:flutter/material.dart';

import '../theme/app_dark.dart';

/// The app's bottom bar: a dark rounded dock with five slots (Students,
/// Promotion, Scan, Achievement, Settings) and the Scan button raised above the
/// middle of it as a red circle with a soft glow.
///
/// Scan is an action, not a page, so it is never the highlighted slot. The
/// highlighted slot has a crimson icon and label and a short crimson underline.
/// The Settings slot carries a small red dot while a backup is due.
///
/// The bar keeps clear of the system navigation area, and its labels cannot
/// outgrow their slots whatever the text size is set to.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.selected,
    required this.onSelected,
    this.showSettingsBadge = false,
  });

  /// The slot that is highlighted (never [scanSlot]).
  final int selected;

  /// Called with the slot that was tapped, including [scanSlot].
  final ValueChanged<int> onSelected;

  /// Shows the small red dot on the Settings slot.
  final bool showSettingsBadge;

  /// The middle slot, where the raised Scan button sits.
  static const int scanSlot = 2;

  static const int settingsSlot = 4;

  /// The labels of the five slots, left to right.
  static const List<String> labels = [
    'Students',
    'Promotion',
    'Scan',
    'Achievement',
    'Settings',
  ];

  static const List<IconData> _icons = [
    Icons.groups_outlined,
    Icons.emoji_events_outlined,
    Icons.qr_code_scanner,
    Icons.workspace_premium_outlined,
    Icons.settings_outlined,
  ];

  static const List<IconData> _activeIcons = [
    Icons.groups,
    Icons.emoji_events,
    Icons.qr_code_scanner,
    Icons.workspace_premium,
    Icons.settings,
  ];

  /// Height of the dock itself, above the system navigation area.
  static const double _barHeight = 64;

  /// How far the Scan button rises above the dock.
  static const double _overhang = 30;

  @override
  Widget build(BuildContext context) {
    // The dock stands clear of the gesture bar / navigation buttons.
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: SizedBox(
        // The Scan button rises into this area, which is part of the bar so it
        // can be tapped there.
        height: _overhang + _barHeight + inset,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _barHeight + inset,
              child: _dock(inset),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: _ScanButton(onTap: () => onSelected(scanSlot)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dock(double inset) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppDark.navBar,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: const Border(top: BorderSide(color: AppDark.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppDark.isLight ? 0.10 : 0.45),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 0, 8, inset),
        child: Row(
          children: [
            for (var slot = 0; slot < labels.length; slot++)
              Expanded(
                child: slot == scanSlot
                    ? _ScanLabel(onTap: () => onSelected(scanSlot))
                    : _NavItem(
                        icon: _icons[slot],
                        activeIcon: _activeIcons[slot],
                        label: labels[slot],
                        selected: slot == selected,
                        // Only the Settings slot has a dot to show: null means
                        // this slot never carries one.
                        showBadge: slot == settingsSlot
                            ? showSettingsBadge
                            : null,
                        onTap: () => onSelected(slot),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One of the four destination slots: an outlined icon over a label, and a
/// crimson underline that grows in under the active one.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.showBadge,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;

  /// Whether the red dot is shown, or null for a slot that has no dot at all
  /// (every slot but Settings), which then draws no badge widget.
  final bool? showBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppDark.crimson : AppDark.icon;
    final iconWidget = Icon(
      selected ? activeIcon : icon,
      size: 24,
      color: color,
    );
    final badge = showBadge;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: AppDark.crimson.withValues(alpha: 0.14),
          highlightColor: AppDark.crimson.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 6, 2, 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (badge == null)
                  iconWidget
                else
                  Badge(
                    isLabelVisible: badge,
                    smallSize: 9,
                    backgroundColor: AppDark.crimson,
                    child: iconWidget,
                  ),
                const SizedBox(height: 3),
                // Scales down rather than clipping, so "Achievement" always
                // fits its slot on the narrowest phone.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 160),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppDark.crimson : AppDark.textSecondary,
                    ),
                    child: Text(label, maxLines: 1, softWrap: false),
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: selected ? 26 : 0,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppDark.crimson,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Scan" label under the raised button, in the middle slot of the dock.
/// Tapping it scans too, which gives the button a bigger target.
class _ScanLabel extends StatelessWidget {
  const _ScanLabel({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: const Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(bottom: 9),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Scan',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppDark.icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The raised circular Scan button: a crimson gradient disc with a white QR
/// scanner icon, a soft red glow, and a ring in the dock's colour that cuts a
/// notch into the dock's top edge. It shrinks slightly while pressed.
class _ScanButton extends StatefulWidget {
  const _ScanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<_ScanButton> {
  static const double _diameter = 60;
  static const double _ring = 5;

  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Scan attendance QR code',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            width: _diameter + _ring * 2,
            height: _diameter + _ring * 2,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppDark.navBar,
              shape: BoxShape.circle,
            ),
            child: Container(
              width: _diameter,
              height: _diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppDark.crimsonGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppDark.crimson.withValues(alpha: 0.55),
                    blurRadius: 22,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.qr_code_scanner,
                size: 30,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
