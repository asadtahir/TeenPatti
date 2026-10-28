import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:teen_patti_engine/teen_patti_engine.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../shared/animations/ambient.dart';
import '../../../shared/animations/entrance.dart';
import '../../../shared/widgets/card_views.dart';
import '../../../shared/widgets/suit_shapes.dart';

/// Three aces (a "trail", the best hand) dealt onto the screen and then floating gently,
/// over a golden halo.
class HeroLogo extends StatelessWidget {
  const HeroLogo({super.key, this.cardWidth = 92});
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final h = cardHeightFor(cardWidth);
    final width = cardWidth * 3.1;
    final height = h * 1.18;

    Widget card(Suit suit, double angle, double dx, double dy, int order) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Entrance(
          delay: Duration(milliseconds: 150 + 140 * order),
          duration: const Duration(milliseconds: 750),
          offset: Offset(0, h * 1.1),
          scaleFrom: 0.6,
          curve: Curves.easeOutBack,
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.rotate(
              angle: angle,
              alignment: Alignment.bottomCenter,
              child: CardFace(
                card: PlayingCard(Rank.ace, suit),
                width: cardWidth,
              ),
            ),
          ),
        ),
      );
    }

    return LoopAnimation(
      period: const Duration(milliseconds: 3200),
      builder: (context, t, child) {
        final bob =
            math.sin(t * math.pi) *
            -6; // t is ping-pong 0..1, so this eases up and down
        return Transform.translate(offset: Offset(0, bob), child: child);
      },
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Halo behind the cards.
            Positioned.fill(
              child: Entrance(
                duration: const Duration(milliseconds: 900),
                offset: Offset.zero,
                scaleFrom: 0.4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        AppColors.gold.withValues(alpha: 0.38),
                        AppColors.gold.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            card(Suit.hearts, -0.42, -cardWidth * 0.82, h * 0.06, 0),
            card(Suit.diamonds, 0.42, cardWidth * 0.82, h * 0.06, 1),
            card(Suit.spades, 0, 0, 0, 2),
          ],
        ),
      ),
    );
  }
}

/// "TEEN PATTI" in gold, with a highlight that sweeps across the letters.
class GoldTitle extends StatelessWidget {
  const GoldTitle({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return LoopAnimation(
      period: const Duration(milliseconds: 3600),
      reverse: false,
      builder: (context, t, child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          colors: const [
            AppColors.gold,
            AppColors.gold,
            Color(0xFFFFF4C7),
            AppColors.gold,
            AppColors.gold,
          ],
          stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
          transform: _SweepTransform(-1.5 + 3 * t),
        ).createShader(bounds),
        child: child,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text.toUpperCase(),
          maxLines: 1,
          style: AppText.display.copyWith(
            fontSize: 46,
            fontWeight: FontWeight.w900,
            letterSpacing: 5,
            color: Colors.white,
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SweepTransform extends GradientTransform {
  const _SweepTransform(this.percent);
  final double percent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * percent, 0, 0);
}

/// A row of the four suits as a decorative divider.
class SuitDivider extends StatelessWidget {
  const SuitDivider({super.key});

  @override
  Widget build(BuildContext context) {
    Widget line() => Expanded(
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.gold.withValues(alpha: 0),
              AppColors.gold.withValues(alpha: 0.6),
            ],
          ),
        ),
      ),
    );
    return Row(
      children: [
        line(),
        const SizedBox(width: AppSpacing.sm),
        for (final s in [Suit.spades, Suit.hearts, Suit.clubs, Suit.diamonds])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: SuitGlyph(
              s,
              size: 14,
              color: s.isRed ? AppColors.crimson : AppColors.gold,
            ),
          ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Transform.flip(
            flipX: true,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.gold.withValues(alpha: 0),
                    AppColors.gold.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
