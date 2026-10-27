import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

/// A casino-style chip.
class ChipDisc extends StatelessWidget {
  const ChipDisc({super.key, this.size = 24, this.color = AppColors.crimson});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ChipPainter(color)),
    );
  }
}

class _ChipPainter extends CustomPainter {
  _ChipPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c + Offset(0, r * 0.12), r, Paint()..color = Colors.black38);
    canvas.drawCircle(c, r, Paint()..color = color);
    // Edge dashes.
    final dash = Paint()
      ..color = Colors.white
      ..strokeWidth = r * 0.22
      ..strokeCap = StrokeCap.butt;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * (r * 0.78),
          c + Offset(math.cos(a), math.sin(a)) * (r * 0.98), dash);
    }
    canvas.drawCircle(
        c, r * 0.62, Paint()..color = AppColors.gold..style = PaintingStyle.stroke..strokeWidth = r * 0.1);
    canvas.drawCircle(c, r * 0.5, Paint()..color = color.withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(_ChipPainter old) => old.color != color;
}

/// Chips stacked by pot size (purely visual).
class ChipStack extends StatelessWidget {
  const ChipStack({super.key, required this.amount, this.chipSize = 26});
  final int amount;
  final double chipSize;

  @override
  Widget build(BuildContext context) {
    final n = amount <= 0 ? 0 : (1 + (math.log(amount.toDouble() + 1) / math.ln10).floor()).clamp(1, 6);
    return SizedBox(
      width: chipSize * 1.4,
      height: chipSize * 1.1 + n * chipSize * 0.14,
      child: Stack(clipBehavior: Clip.none, children: [
        for (var i = 0; i < n; i++)
          Positioned(
            left: (chipSize * 0.2) + (i.isOdd ? 2 : 0),
            bottom: i * chipSize * 0.14,
            child: ChipDisc(
                size: chipSize,
                color: i % 3 == 0 ? AppColors.crimson : (i % 3 == 1 ? const Color(0xFF1F6FEB) : AppColors.success)),
          ),
      ]),
    );
  }
}
