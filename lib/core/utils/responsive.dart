import 'package:flutter/widgets.dart';

enum ScreenClass { compact, medium, expanded }

extension ResponsiveContext on BuildContext {
  ScreenClass get screenClass {
    final w = MediaQuery.sizeOf(this).shortestSide;
    if (w < 400) return ScreenClass.compact;
    if (w < 700) return ScreenClass.medium;
    return ScreenClass.expanded;
  }

  /// Scale factor for sizes relative to a 400dp-wide reference phone.
  double get scale =>
      (MediaQuery.sizeOf(this).shortestSide / 400).clamp(0.8, 1.6);
}
