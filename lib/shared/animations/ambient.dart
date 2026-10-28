import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teen_patti_engine/teen_patti_engine.dart' show Suit;

import '../../core/theme/design_tokens.dart';
import '../widgets/suit_shapes.dart';
import 'animation_profile.dart';

/// Whether endlessly looping decoration (floating suits, shimmer, glow pulses) should run.
/// Off for "Reduce animations" and Low graphics quality; tests turn it off so screens settle.
final ambientMotionProvider = Provider<bool>((ref) {
  final p = ref.watch(animationProfileProvider);
  return !p.reduced && p.particles > 0;
});

/// Drives [builder] with a value that loops 0..1 (or ping-pongs when [reverse]) while ambient
/// motion is enabled, and rests at 0 otherwise.
class LoopAnimation extends ConsumerStatefulWidget {
  const LoopAnimation({
    super.key,
    required this.builder,
    this.period = const Duration(seconds: 3),
    this.reverse = true,
    this.child,
  });

  final Widget Function(BuildContext context, double t, Widget? child) builder;
  final Duration period;
  final bool reverse;
  final Widget? child;

  @override
  ConsumerState<LoopAnimation> createState() => _LoopAnimationState();
}

class _LoopAnimationState extends ConsumerState<LoopAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = ref.watch(ambientMotionProvider);
    if (on && !_c.isAnimating) {
      _c.repeat(reverse: widget.reverse);
    } else if (!on && _c.isAnimating) {
      _c.stop();
    }
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => widget.builder(context, _c.value, child),
    );
  }
}

/// Slowly rising card suits and a breathing spotlight behind the menu screens.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: LoopAnimation(
          period: const Duration(seconds: 60),
          reverse: false,
          builder: (context, t, _) =>
              CustomPaint(painter: _AmbientPainter(t), size: Size.infinite),
        ),
      ),
    );
  }
}

class _Floater {
  const _Floater(
    this.suit,
    this.x,
    this.size,
    this.phase,
    this.rise,
    this.sway,
    this.spin,
  );
  final Suit suit;
  final double x;
  final double size;
  final double phase;
  final int rise;
  final int sway;
  final int spin;
}

final _floaters = () {
  final r = math.Random(7);
  return [
    for (var i = 0; i < 14; i++)
      _Floater(
        Suit.values[i % Suit.values.length],
        r.nextDouble(),
        26 + r.nextDouble() * 46,
        r.nextDouble(),
        1 + r.nextInt(2),
        2 + r.nextInt(3),
        r.nextBool() ? 1 : -1,
      ),
  ];
}();

class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Breathing spotlight.
    final glow = 0.5 + 0.5 * math.sin(2 * math.pi * t * 4);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.55),
          radius: 0.9,
          colors: [
            AppColors.gold.withValues(alpha: 0.05 + 0.04 * glow),
            Colors.transparent,
          ],
        ).createShader(Offset.zero & size),
    );

    for (final f in _floaters) {
      final progress = (t * f.rise + f.phase) % 1.0;
      final y = size.height * (1.1 - progress * 1.25);
      final x =
          size.width * f.x +
          math.sin(2 * math.pi * (t * f.sway + f.phase)) * 14;
      final fade = math.sin(math.pi * progress);
      final color = (f.suit.isRed ? AppColors.crimson : AppColors.gold)
          .withValues(alpha: 0.12 * fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(2 * math.pi * f.spin * t);
      paintSuit(canvas, f.suit, f.size, color);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter old) => old.t != t;
}
