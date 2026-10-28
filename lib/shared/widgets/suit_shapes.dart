import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:teen_patti_engine/teen_patti_engine.dart' show Suit;

/// Vector card suits drawn in a unit square, so they stay crisp at any size and do not
/// depend on a font having the glyphs.
Path suitPath(Suit suit) => _paths.putIfAbsent(suit, () => _build(suit));

final _paths = <Suit, Path>{};

Path _union(Path a, Path b) => Path.combine(PathOperation.union, a, b);

Path _circle(double x, double y, double r) =>
    Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));

Path _poly(List<Offset> pts) => Path()..addPolygon(pts, true);

Path _heart() => _union(
  _union(_circle(0.29, 0.34, 0.27), _circle(0.71, 0.34, 0.27)),
  _poly(const [Offset(0.06, 0.46), Offset(0.94, 0.46), Offset(0.5, 0.97)]),
);

/// Column-major 4x4 for a 180 degree rotation about the centre of the unit square.
final _rotate180 = Float64List.fromList([
  -1,
  0,
  0,
  0,
  0,
  -1,
  0,
  0,
  0,
  0,
  1,
  0,
  1,
  1,
  0,
  1,
]);

Path _build(Suit suit) {
  switch (suit) {
    case Suit.hearts:
      return _heart();
    case Suit.spades:
      final body = _heart().transform(_rotate180);
      return _union(
        body,
        _poly(const [
          Offset(0.42, 0.66),
          Offset(0.58, 0.66),
          Offset(0.72, 0.98),
          Offset(0.28, 0.98),
        ]),
      );
    case Suit.diamonds:
      return _poly(const [
        Offset(0.5, 0.02),
        Offset(0.88, 0.5),
        Offset(0.5, 0.98),
        Offset(0.12, 0.5),
      ]);
    case Suit.clubs:
      return _union(
        _union(_circle(0.5, 0.27, 0.23), _circle(0.26, 0.6, 0.23)),
        _union(
          _circle(0.74, 0.6, 0.23),
          _poly(const [
            Offset(0.43, 0.55),
            Offset(0.57, 0.55),
            Offset(0.7, 0.98),
            Offset(0.3, 0.98),
          ]),
        ),
      );
  }
}

/// Paints [suit] centred on the canvas origin with the given [size].
void paintSuit(Canvas canvas, Suit suit, double size, Color color) {
  canvas.save();
  canvas.translate(-size / 2, -size / 2);
  canvas.scale(size);
  canvas.drawPath(suitPath(suit), Paint()..color = color);
  canvas.restore();
}

/// A card suit symbol of the given [size], drawn as a vector.
class SuitGlyph extends StatelessWidget {
  const SuitGlyph(this.suit, {super.key, required this.size, required this.color});
  final Suit suit;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _GlyphPainter(suit, color)));
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.suit, this.color);
  final Suit suit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    paintSuit(canvas, suit, size.width, color);
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.suit != suit || old.color != color;
}
