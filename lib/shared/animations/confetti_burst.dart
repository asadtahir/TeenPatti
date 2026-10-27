import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

/// One-shot confetti burst from a point. [count] of 0 renders nothing.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, required this.count, this.duration = const Duration(milliseconds: 1800), this.seed = 1});
  final int count;
  final Duration duration;
  final int seed;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)..forward();
  late final List<_Particle> _particles;

  static const _colors = [AppColors.gold, AppColors.crimson, AppColors.success, Colors.white, Color(0xFF5AA9FF)];

  @override
  void initState() {
    super.initState();
    final r = math.Random(widget.seed);
    _particles = [
      for (var i = 0; i < widget.count; i++)
        _Particle(
          angle: -math.pi / 2 + (r.nextDouble() - 0.5) * math.pi * 1.1,
          speed: 180 + r.nextDouble() * 320,
          spin: (r.nextDouble() - 0.5) * 12,
          size: 4 + r.nextDouble() * 5,
          color: _colors[r.nextInt(_colors.length)],
        ),
    ];
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count == 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_particles, _c.value),
          ),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({required this.angle, required this.speed, required this.spin, required this.size, required this.color});
  final double angle, speed, spin, size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.t);
  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.45);
    final secs = t * 1.8;
    for (final p in particles) {
      final dx = math.cos(p.angle) * p.speed * secs;
      final dy = math.sin(p.angle) * p.speed * secs + 420 * secs * secs;
      final opacity = (1 - t).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(origin.dx + dx, origin.dy + dy);
      canvas.rotate(p.spin * secs);
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
          Paint()..color = p.color.withValues(alpha: opacity));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
