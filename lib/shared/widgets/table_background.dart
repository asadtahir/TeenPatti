import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

/// Felt-style backdrop shared by the menu screens.
class TableBackground extends StatelessWidget {
  const TableBackground({super.key, required this.child, this.dark = false});
  final Widget child;

  /// A near-black room so the felt table stands out (used on the game screen).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.3),
            radius: 1.2,
            colors: dark
                ? const [Color(0xFF16222B), AppColors.night, AppColors.night]
                : const [AppColors.feltLight, AppColors.felt, AppColors.feltDark, AppColors.night],
            stops: dark ? const [0, 0.6, 1] : const [0, 0.35, 0.7, 1],
          ),
        ),
        child: SafeArea(child: child),
      ),
    );
  }
}
