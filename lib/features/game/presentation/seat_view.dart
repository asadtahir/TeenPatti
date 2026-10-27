import 'package:flutter/material.dart';
import 'package:teen_patti_engine/teen_patti_engine.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../shared/animations/turn_ring.dart';
import '../../../shared/widgets/card_views.dart';
import '../../../shared/widgets/chip_badge.dart';

class SeatView extends StatelessWidget {
  const SeatView({
    super.key,
    required this.player,
    required this.isLocal,
    required this.isTurn,
    required this.isDealer,
    required this.isWinner,
    required this.avatarSize,
    required this.cardWidth,
    required this.visibleCards,
    required this.flipDuration,
    this.turnRemaining,
    this.turnTotal,
    this.onWarningTick,
    this.glow = true,
  });

  final PlayerState player;
  final bool isLocal;
  final bool isTurn;
  final bool isDealer;
  final bool isWinner;
  final double avatarSize;
  final double cardWidth;

  /// How many of the 3 cards have been dealt so far (deal animation).
  final int visibleCards;
  final Duration flipDuration;
  final Duration? turnRemaining;
  final Duration? turnTotal;
  final void Function(int)? onWarningTick;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final folded = player.folded;
    final hasHand = player.hand.length == 3;
    final overlap = isLocal ? 0.62 : 0.5;

    final cards = SizedBox(
      width: cardWidth * (1 + 2 * overlap),
      height: cardHeightFor(cardWidth) + (isWinner ? 0 : 0),
      child: Stack(children: [
        for (var i = 0; i < 3; i++)
          if (i < visibleCards)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              left: cardWidth * overlap * i,
              top: isWinner ? -cardWidth * 0.12 : 0,
              child: Transform.rotate(
                angle: (i - 1) * 0.07,
                child: FlipCard(
                  width: cardWidth,
                  card: hasHand ? player.hand[i] : null,
                  faceUp: hasHand,
                  duration: flipDuration,
                ),
              ),
            ),
      ]),
    );

    final avatar = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceHigh,
        border: Border.all(
            color: isWinner ? AppColors.gold : Colors.white24, width: isWinner ? 3 : 1.5),
        boxShadow: isWinner && glow ? AppShadows.glow : null,
      ),
      child: Icon(player.isBot ? Icons.smart_toy_outlined : Icons.person,
          color: isLocal ? AppColors.gold : AppColors.textMuted, size: avatarSize * 0.55),
    );

    Widget avatarWidget = avatar;
    if (isTurn) {
      avatarWidget = turnRemaining != null && turnTotal != null
          ? TurnRing(
              key: ValueKey('ring-${player.id}-${turnRemaining!.inMilliseconds ~/ 100000}'),
              size: avatarSize + 10,
              remaining: turnRemaining!,
              total: turnTotal!,
              onWarningTick: isLocal ? onWarningTick : null,
              child: avatar,
            )
          : Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: 2),
                boxShadow: glow ? AppShadows.glow : null,
              ),
              child: avatar,
            );
    }

    final (label, labelColor) = folded
        ? ('PACKED', AppColors.textMuted)
        : player.seen
            ? ('SEEN', AppColors.success)
            : ('BLIND', AppColors.warning);

    return Opacity(
      opacity: folded ? 0.5 : 1,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (isLocal && isTurn)
          const Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Text('YOUR TURN',
                style: TextStyle(
                    color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
          ),
        cards,
        const SizedBox(height: 4),
        Stack(clipBehavior: Clip.none, children: [
          avatarWidget,
          if (isDealer)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Text('D',
                    style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
          if (isWinner)
            const Positioned(
                top: -14, left: 0, right: 0, child: Icon(Icons.emoji_events, color: AppColors.gold, size: 20)),
        ]),
        const SizedBox(height: 4),
        Container(
          constraints: BoxConstraints(maxWidth: avatarSize * 1.9),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(isLocal ? 'You' : player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(formatChips(player.chips),
                style: const TextStyle(fontSize: 11, color: AppColors.gold, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.w800, color: labelColor)),
      ]),
    );
  }
}
