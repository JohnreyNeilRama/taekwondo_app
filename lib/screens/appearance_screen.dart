import 'package:flutter/material.dart';

import '../services/appearance_settings.dart';
import '../theme/app_dark.dart';
import '../widgets/app_page.dart';
import '../widgets/empty_state_card.dart';

/// Appearance: light or dark, and how large the text of the whole app is.
///
/// A choice applies at once, to this page too, so the page itself shows what
/// the app will look like. Both are saved on this device and used the next time
/// the app opens.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  Future<void> _choose(BuildContext context, AppTextSize size) async {
    if (size == AppearanceSettings.textSize.value) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppearanceSettings().saveTextSize(size);
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save this setting. It will last until the app is '
              'closed.',
            ),
          ),
        );
    }
  }

  Future<void> _setLightMode(BuildContext context, bool light) async {
    if (light == AppearanceSettings.lightMode.value) return;
    // Taken before the switch: the page is built again in the new palette while
    // the choice is being saved, and this belongs to the app, not to the page.
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppearanceSettings().saveLightMode(light);
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save this setting. It will last until the app is '
              'closed.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // A new key when the mode changes builds the whole page again, so every
    // colour on it (the const ones included) is read in the new palette.
    return ValueListenableBuilder<bool>(
      valueListenable: AppearanceSettings.lightMode,
      builder: (context, light, _) => AppPage(
        key: ValueKey<bool>(light),
        title: 'Appearance',
        subtitle: 'How the app looks',
        child: ValueListenableBuilder<AppTextSize>(
          valueListenable: AppearanceSettings.textSize,
          builder: (context, selected, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                const SectionLabel('THEME'),
                const SizedBox(height: 10),
                _LightModeCard(
                  light: light,
                  onChanged: (value) => _setLightMode(context, value),
                ),
                const SizedBox(height: 28),
                const SectionLabel('TEXT SIZE'),
                const SizedBox(height: 6),
                const Text(
                  'Makes the text larger or smaller across the whole app. '
                  'It is added to the text size set on your phone.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppDark.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                const _Preview(),
                const SizedBox(height: 16),
                _SizeOptions(
                  selected: selected,
                  onSelected: (size) => _choose(context, size),
                ),
                const SizedBox(height: 16),
                const NoticeCard(
                  icon: Icons.info_outline,
                  message:
                      'Buttons and the bottom bar keep a size that stays easy '
                      'to tap, whichever text size you choose.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The Light mode switch: one card, and the whole card is the button.
class _LightModeCard extends StatelessWidget {
  const _LightModeCard({required this.light, required this.onChanged});

  final bool light;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: light,
      label: 'Light mode',
      child: DarkCard(
        onTap: () => onChanged(!light),
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            IconPlate(
              icon: light ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 46,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Light mode',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppDark.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    light
                        ? 'On \u00B7 bright pages, dark header'
                        : 'Off \u00B7 dark pages',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: AppDark.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(value: light, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// A sample of what a student's card says, drawn at the chosen size.
class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    return const DarkCard(
      accent: AppDark.crimson,
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PREVIEW',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: AppDark.textSecondary,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Dela Cruz, Juan Miguel',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppDark.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '"Johnny"',
            style: TextStyle(fontSize: 14, color: AppDark.textSecondary),
          ),
          SizedBox(height: 2),
          Text(
            'Rizal High School',
            style: TextStyle(fontSize: 14, color: AppDark.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// The four sizes, one tappable row each, in one card.
class _SizeOptions extends StatelessWidget {
  const _SizeOptions({required this.selected, required this.onSelected});

  final AppTextSize selected;
  final ValueChanged<AppTextSize> onSelected;

  @override
  Widget build(BuildContext context) {
    final sizes = AppTextSize.values;
    return Container(
      decoration: BoxDecoration(
        color: AppDark.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDark.border),
        boxShadow: AppDark.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < sizes.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            _SizeRow(
              size: sizes[i],
              selected: sizes[i] == selected,
              onTap: () => onSelected(sizes[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _SizeRow extends StatelessWidget {
  const _SizeRow({
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final AppTextSize size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        splashColor: AppDark.crimson.withValues(alpha: 0.12),
        highlightColor: AppDark.crimson.withValues(alpha: 0.06),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // A fixed-size "Aa" in each row's own scale, so the rows show
                // the steps without growing with the setting itself.
                SizedBox(
                  width: 44,
                  child: Text(
                    'Aa',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: 16 * size.factor,
                      fontWeight: FontWeight.w800,
                      color: selected ? AppDark.crimson : AppDark.icon,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    size.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: AppDark.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    key: ValueKey(selected),
                    size: 24,
                    color: selected ? AppDark.crimson : AppDark.textSecondary,
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
