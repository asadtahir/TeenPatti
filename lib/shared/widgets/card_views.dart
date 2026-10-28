import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:teen_patti_engine/teen_patti_engine.dart';

import '../../core/theme/design_tokens.dart';
import 'suit_shapes.dart';

double cardHeightFor(double width) => width / AppCardSize.aspect;

/// Face of a playing card.
class CardFace extends StatelessWidget {
  const CardFace({super.key, required this.card, required this.width});
  final PlayingCard card;
  final double width;

  @override
  Widget build(BuildContext context) {
    final color = card.suit.isRed ? const Color(0xFFC62828) : const Color(0xFF1B1B1B);
    final h = cardHeightFor(width);
    return Semantics(
      label: '${card.rank.label} of ${card.suit.name}',
      child: Container(
        width: width,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFEDE7DA)],
          ),
          border: Border.all(color: Colors.black12),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: Stack(children: [
          Positioned(
            left: width * 0.09,
            top: h * 0.05,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(card.rank.label,
                  style: TextStyle(
                      color: color, fontSize: width * 0.34, fontWeight: FontWeight.w800, height: 1)),
              Padding(
                padding: EdgeInsets.only(top: width * 0.03),
                child: SuitGlyph(card.suit, size: width * 0.26, color: color),
              ),
            ]),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: h * 0.12, left: width * 0.1),
              child: SuitGlyph(card.suit, size: width * 0.56, color: color.withValues(alpha: 0.92)),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Teen Patti themed card back.
class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = cardHeightFor(width);
    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.12),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.12),
        child: CustomPaint(painter: _BackPainter(), size: Size(width, h)),
      ),
    );
  }
}

class _BackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8E1B2E), Color(0xFF4A0E1A)],
          ).createShader(rect));
    final inset = size.width * 0.07;
    final inner = rect.deflate(inset);
    canvas.drawRRect(
        RRect.fromRectAndRadius(inner, Radius.circular(size.width * 0.07)),
        Paint()
          ..color = AppColors.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, size.width * 0.025));

    // Diamond lattice.
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(inner.deflate(size.width * 0.03), Radius.circular(size.width * 0.05)));
    final lattice = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    final step = size.width * 0.2;
    for (double d = -size.height; d < size.width + size.height; d += step) {
      canvas.drawLine(Offset(d, 0), Offset(d + size.height, size.height), lattice);
      canvas.drawLine(Offset(d, size.height), Offset(d + size.height, 0), lattice);
    }
    canvas.restore();

    // Center medallion.
    final c = rect.center;
    final r = size.width * 0.26;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF2A0710));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = AppColors.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, size.width * 0.02));
    final tp = TextPainter(
      text: TextSpan(
          text: 'AT',
          style: TextStyle(
              color: AppColors.gold, fontSize: r * 0.95, fontWeight: FontWeight.w900, letterSpacing: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Card that flips around the Y axis between back and face.
class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.width,
    this.card,
    required this.faceUp,
    this.duration = AppDurations.cardFlip,
  });

  final double width;

  /// Null means the face is unknown (never shown).
  final PlayingCard? card;
  final bool faceUp;
  final Duration duration;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: widget.duration, value: widget.faceUp && widget.card != null ? 1 : 0);

  @override
  void didUpdateWidget(FlipCard old) {
    super.didUpdateWidget(old);
    _c.duration = widget.duration;
    final target = widget.faceUp && widget.card != null;
    if (target && _c.status != AnimationStatus.forward && _c.value < 1) {
      _c.forward();
    } else if (!target && _c.value > 0) {
      _c.reverse();
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
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(_c.value);
          final angle = t * math.pi;
          final showFront = t >= 0.5 && widget.card != null;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(showFront ? angle - math.pi : angle);
          return Transform(
            alignment: Alignment.center,
            transform: transform,
            child: showFront
                ? CardFace(card: widget.card!, width: widget.width)
                : CardBack(width: widget.width),
          );
        },
      ),
    );
  }
}
