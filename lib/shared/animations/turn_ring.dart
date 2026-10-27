import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

/// Circular countdown around an avatar. Colour shifts and pulses near the end.
class TurnRing extends StatefulWidget {
  const TurnRing({
    super.key,
    required this.size,
    required this.remaining,
    required this.total,
    this.onWarningTick,
    this.pulse = true,
    required this.child,
  });

  final double size;
  final Duration remaining;
  final Duration total;

  /// Called once per second during the last 3 seconds.
  final void Function(int secondsLeft)? onWarningTick;
  final bool pulse;
  final Widget child;

  @override
  State<TurnRing> createState() => _TurnRingState();
}

class _TurnRingState extends State<TurnRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  int _lastWhole = 1 << 30;

  @override
  void initState() {
    super.initState();
    final rem = widget.remaining > widget.total ? widget.total : widget.remaining;
    _c = AnimationController(vsync: this, duration: widget.total, value: 1 - _frac(rem))
      ..addListener(_tick)
      ..forward();
  }

  double _frac(Duration rem) =>
      widget.total.inMilliseconds == 0 ? 1 : rem.inMilliseconds / widget.total.inMilliseconds;

  void _tick() {
    final left = (widget.total.inMilliseconds * (1 - _c.value) / 1000).ceil();
    if (left != _lastWhole) {
      _lastWhole = left;
      if (left > 0 && left <= 3) widget.onWarningTick?.call(left);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final left = 1 - _c.value;
          final secs = widget.total.inMilliseconds * left / 1000;
          final color = Color.lerp(AppColors.crimson, AppColors.success, (left * 1.6).clamp(0.0, 1.0))!;
          final urgent = secs <= 3 && widget.pulse;
          final pulse = urgent ? 1 + 0.06 * math.sin(_c.value * math.pi * 2 * secs.ceil() * 4) : 1.0;
          return Transform.scale(
            scale: pulse,
            child: CustomPaint(
              painter: _RingPainter(left, color),
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: Padding(padding: const EdgeInsets.all(5), child: child),
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color);
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2);
    canvas.drawArc(rect, 0, math.pi * 2, false,
        Paint()..color = Colors.white12..style = PaintingStyle.stroke..strokeWidth = 4);
    canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * fraction,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color;
}
