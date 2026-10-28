import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../animations/ambient.dart';

/// Felt-style backdrop shared by the menu screens.
class TableBackground extends StatelessWidget {
  const TableBackground({super.key, required this.child, this.dark = false});
  final Widget child;

  /// A near-black room so the felt table stands out (used on the game screen).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.3),
                  radius: 1.2,
                  colors: dark
                      ? const [
                          Color(0xFF16222B),
                          AppColors.night,
                          AppColors.night,
                        ]
                      : const [
                          AppColors.feltLight,
                          AppColors.felt,
                          AppColors.feltDark,
                          AppColors.night,
                        ],
                  stops: dark ? const [0, 0.6, 1] : const [0, 0.35, 0.7, 1],
                ),
              ),
            ),
          ),
        ),
        // Menu screens get drifting suits; the game table stays calm so cards stay the focus.
        if (!dark) const Positioned.fill(child: AmbientBackground()),
        Positioned.fill(child: SafeArea(child: child)),
      ],
    );
  }
}
