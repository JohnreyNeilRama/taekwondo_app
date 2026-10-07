import 'package:flutter/material.dart';

import '../theme/app_dark.dart';
import 'registry_header.dart';

/// The top bar with the TKD logo and app title, kept for the pages that built
/// it before the shared [RegistryHeader]: it now simply draws that header, with
/// an optional widget shown underneath. [actions] are icon buttons placed at the
/// right end of the bar.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.bottom, this.actions = const []});

  final Widget? bottom;

  /// Buttons shown at the right end of the title row, e.g. the Trash button.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final header = RegistryHeader(actions: actions);
    if (bottom == null) return header;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        ColoredBox(
          color: AppDark.headerBottom,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: bottom,
          ),
        ),
      ],
    );
  }
}
