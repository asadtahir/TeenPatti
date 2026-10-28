import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

/// A friendly cartoon portrait drawn with vectors. The look is derived from [seed] (a name or
/// id), so every player keeps the same face and bots are easy to tell apart.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.seed,
    required this.size,
    this.border,
    this.shadows,
    this.highlight = false,
  });

  final String seed;
  final double size;
  final Border? border;
  final List<BoxShadow>? shadows;

  /// The local player gets a gold backdrop.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: border,
        boxShadow: shadows,
      ),
      child: ClipOval(
        child: CustomPaint(painter: _FacePainter(seed, highlight)),
      ),
    );
  }
}

enum _Hair { short, long, bun, cap, bald, curly }

class _Look {
  _Look({
    required this.bgA,
    required this.bgB,
    required this.skin,
    required this.hairColor,
    required this.shirt,
    required this.hair,
    required this.glasses,
    required this.moustache,
  });

  final Color bgA, bgB, skin, hairColor, shirt;
  final _Hair hair;
  final bool glasses, moustache;

  static const _bgs = [
    (Color(0xFF2E6FDB), Color(0xFF123A7A)),
    (Color(0xFF8E44AD), Color(0xFF4A1E63)),
    (Color(0xFFE67E22), Color(0xFF8A4310)),
    (Color(0xFF16A085), Color(0xFF08594A)),
    (Color(0xFFD7263D), Color(0xFF6E0F1D)),
    (Color(0xFF5D6D7E), Color(0xFF2B3640)),
  ];
  static const _skins = [
    Color(0xFFF1C6A0),
    Color(0xFFE0A877),
    Color(0xFFC68642),
    Color(0xFF8D5524),
    Color(0xFFFFDBB4),
  ];
  static const _hairs = [
    Color(0xFF1B1B1B),
    Color(0xFF3B2314),
    Color(0xFF6B3E1E),
    Color(0xFF8A8A8A),
    Color(0xFF9C2F1A),
  ];
  static const _shirts = [
    Color(0xFFF4F1E8),
    Color(0xFF22313F),
    Color(0xFFB03A48),
    Color(0xFF2F8F6B),
    Color(0xFFE8B84A),
  ];

  static _Look from(String seed, bool highlight) {
    // Stable FNV-1a hash: String.hashCode differs between runs.
    var h = 0x811C9DC5;
    for (final c in seed.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7FFFFFFF;
    }
    int pick(int n, int salt) =>
        ((h >> (salt * 3)) ^ (h * (salt + 7))).abs() % n;

    final bg = highlight
        ? (AppColors.goldDark, const Color(0xFF5A4410))
        : _bgs[pick(_bgs.length, 1)];
    final hair = _Hair.values[pick(_Hair.values.length, 2)];
    return _Look(
      bgA: bg.$1,
      bgB: bg.$2,
      skin: _skins[pick(_skins.length, 3)],
      hairColor: _hairs[pick(_hairs.length, 4)],
      shirt: _shirts[pick(_shirts.length, 5)],
      hair: hair,
      glasses: pick(4, 6) == 0,
      moustache: hair != _Hair.long && hair != _Hair.bun && pick(3, 7) == 0,
    );
  }
}

class _FacePainter extends CustomPainter {
  _FacePainter(this.seed, this.highlight) : look = _Look.from(seed, highlight);
  final String seed;
  final bool highlight;
  final _Look look;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.4),
          radius: 1.0,
          colors: [look.bgA, look.bgB],
        ).createShader(rect),
    );

    final hairPaint = Paint()..color = look.hairColor;
    final skin = Paint()..color = look.skin;
    final shade = Paint()..color = Colors.black.withValues(alpha: 0.12);
    final headC = Offset(s * 0.5, s * 0.44);
    final headR = Size(s * 0.25, s * 0.29);

    // Hair that sits behind the head.
    if (look.hair == _Hair.long) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(s * 0.5, s * 0.58),
            width: s * 0.62,
            height: s * 0.66,
          ),
          Radius.circular(s * 0.25),
        ),
        hairPaint,
      );
    }
    if (look.hair == _Hair.bun) {
      canvas.drawCircle(Offset(s * 0.5, s * 0.1), s * 0.1, hairPaint);
    }
    if (look.hair == _Hair.curly) {
      for (final dx in [-0.22, -0.11, 0.0, 0.11, 0.22]) {
        canvas.drawCircle(
          Offset(s * (0.5 + dx), s * (0.2 + dx.abs() * 0.35)),
          s * 0.1,
          hairPaint,
        );
      }
    }

    // Shoulders and neck.
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.04, s * 1.02)
        ..quadraticBezierTo(s * 0.06, s * 0.72, s * 0.5, s * 0.7)
        ..quadraticBezierTo(s * 0.94, s * 0.72, s * 0.96, s * 1.02)
        ..close(),
      Paint()..color = look.shirt,
    );
    final neck = Rect.fromCenter(
      center: Offset(s * 0.5, s * 0.7),
      width: s * 0.16,
      height: s * 0.16,
    );
    canvas.drawRect(neck, skin);
    canvas.drawRect(
      Rect.fromLTWH(neck.left, neck.top, neck.width, s * 0.05),
      shade,
    );

    // Head and ears.
    for (final dx in [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(headC.dx + dx * headR.width * 0.98, headC.dy + s * 0.03),
        s * 0.04,
        skin,
      );
    }
    final head = Rect.fromCenter(
      center: headC,
      width: headR.width * 2,
      height: headR.height * 2,
    );
    canvas.drawOval(head, skin);

    // Hair on top of the head.
    switch (look.hair) {
      case _Hair.short:
      case _Hair.long:
      case _Hair.bun:
        canvas.drawPath(
          Path()
            ..moveTo(head.left - s * 0.01, headC.dy - s * 0.02)
            ..quadraticBezierTo(
              head.left,
              head.top - s * 0.04,
              headC.dx,
              head.top - s * 0.02,
            )
            ..quadraticBezierTo(
              head.right,
              head.top - s * 0.04,
              head.right + s * 0.01,
              headC.dy - s * 0.02,
            )
            ..quadraticBezierTo(
              headC.dx + s * 0.08,
              headC.dy - s * 0.17,
              headC.dx - s * 0.1,
              headC.dy - s * 0.15,
            )
            ..quadraticBezierTo(
              head.left + s * 0.04,
              headC.dy - s * 0.12,
              head.left - s * 0.01,
              headC.dy - s * 0.02,
            )
            ..close(),
          hairPaint,
        );
      case _Hair.cap:
        canvas.drawPath(
          Path()
            ..moveTo(head.left - s * 0.02, headC.dy - s * 0.08)
            ..quadraticBezierTo(
              head.left,
              head.top - s * 0.06,
              headC.dx,
              head.top - s * 0.05,
            )
            ..quadraticBezierTo(
              head.right,
              head.top - s * 0.06,
              head.right + s * 0.02,
              headC.dy - s * 0.08,
            )
            ..close(),
          Paint()
            ..color = look.shirt == const Color(0xFFB03A48)
                ? const Color(0xFF22313F)
                : const Color(0xFFB03A48),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              head.left - s * 0.03,
              headC.dy - s * 0.1,
              headR.width * 2 + s * 0.12,
              s * 0.045,
            ),
            Radius.circular(s * 0.02),
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.35),
        );
      case _Hair.curly:
        canvas.drawArc(
          head.inflate(s * 0.01),
          3.4,
          2.6,
          false,
          Paint()
            ..color = look.hairColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.07,
        );
      case _Hair.bald:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(headC.dx - headR.width * 0.35, head.top + s * 0.07),
            width: s * 0.1,
            height: s * 0.05,
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.25),
        );
    }

    // Face.
    final eyeY = headC.dy + s * 0.01;
    final dark = Paint()..color = const Color(0xFF1B1B1B);
    for (final dx in [-1.0, 1.0]) {
      final e = Offset(headC.dx + dx * s * 0.1, eyeY);
      canvas.drawOval(
        Rect.fromCenter(center: e, width: s * 0.075, height: s * 0.09),
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(e + Offset(0, s * 0.005), s * 0.028, dark);
      canvas.drawCircle(
        e + Offset(-s * 0.008, -s * 0.008),
        s * 0.009,
        Paint()..color = Colors.white,
      );
      canvas.drawLine(
        e + Offset(-s * 0.05, -s * 0.07),
        e + Offset(s * 0.05, -s * 0.07 - dx * s * 0.008),
        Paint()
          ..color = look.hairColor == const Color(0xFF8A8A8A)
              ? const Color(0xFF5A5A5A)
              : look.hairColor
          ..strokeWidth = s * 0.025
          ..strokeCap = StrokeCap.round,
      );
    }
    if (look.glasses) {
      final g = Paint()
        ..color = const Color(0xFF111111)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.02;
      for (final dx in [-1.0, 1.0]) {
        canvas.drawCircle(Offset(headC.dx + dx * s * 0.1, eyeY), s * 0.065, g);
      }
      canvas.drawLine(
        Offset(headC.dx - s * 0.035, eyeY),
        Offset(headC.dx + s * 0.035, eyeY),
        g,
      );
    }
    // Nose.
    canvas.drawPath(
      Path()
        ..moveTo(headC.dx, eyeY + s * 0.03)
        ..quadraticBezierTo(
          headC.dx + s * 0.035,
          eyeY + s * 0.1,
          headC.dx - s * 0.005,
          eyeY + s * 0.115,
        ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.018
        ..strokeCap = StrokeCap.round,
    );
    // Smile.
    final mouthY = headC.dy + s * 0.17;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(headC.dx, mouthY - s * 0.035),
        width: s * 0.17,
        height: s * 0.1,
      ),
      0.25,
      2.65,
      false,
      Paint()
        ..color = const Color(0xFF7A2E2E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.026
        ..strokeCap = StrokeCap.round,
    );
    if (look.moustache) {
      canvas.drawPath(
        Path()
          ..moveTo(headC.dx, mouthY - s * 0.075)
          ..quadraticBezierTo(
            headC.dx - s * 0.08,
            mouthY - s * 0.11,
            headC.dx - s * 0.115,
            mouthY - s * 0.05,
          )
          ..quadraticBezierTo(
            headC.dx - s * 0.05,
            mouthY - s * 0.07,
            headC.dx,
            mouthY - s * 0.055,
          )
          ..quadraticBezierTo(
            headC.dx + s * 0.05,
            mouthY - s * 0.07,
            headC.dx + s * 0.115,
            mouthY - s * 0.05,
          )
          ..quadraticBezierTo(
            headC.dx + s * 0.08,
            mouthY - s * 0.11,
            headC.dx,
            mouthY - s * 0.075,
          ),
        hairPaint,
      );
    }
    // Cheek blush.
    final blush = Paint()
      ..color = const Color(0xFFE5675F).withValues(alpha: 0.22);
    for (final dx in [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(headC.dx + dx * s * 0.155, eyeY + s * 0.09),
        s * 0.035,
        blush,
      );
    }
  }

  @override
  bool shouldRepaint(_FacePainter old) =>
      old.seed != seed || old.highlight != highlight;
}
