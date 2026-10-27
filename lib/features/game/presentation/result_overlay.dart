import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teen_patti_engine/teen_patti_engine.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../shared/widgets/chip_badge.dart';
import '../../../shared/widgets/premium_button.dart';
import 'game_controller.dart';

/// End-of-hand summary: winner, winning hand, chips won.
class ResultOverlay extends ConsumerWidget {
  const ResultOverlay({super.key, required this.game, required this.localId, this.onNext});

  final GameState game;
  final String localId;

  /// Null online (the server/host starts the next hand).
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = game.playerById(localId);
    final iWon = game.winnerIds.contains(localId);
    final winnerNames = game.winnerIds.map((id) => game.playerById(id).name).join(' & ');
    final net = (game.payouts[localId] ?? 0) - me.invested;

    final title = iWon ? 'You Win!' : '$winnerNames wins';
    final hand = game.winningHandName?.toUpperCase() ?? 'EVERYONE ELSE PACKED';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
      ),
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.lg),
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: iWon ? AppColors.gold : Colors.white24, width: 2),
              boxShadow: iWon ? AppShadows.glow : AppShadows.soft,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(hand,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: AppSpacing.sm),
              Text(title, textAlign: TextAlign.center, style: AppText.display.copyWith(fontSize: 32)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                net >= 0 ? '+ ${formatChips(net)}' : '- ${formatChips(-net)}',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: net >= 0 ? AppColors.success : AppColors.crimson),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('Pot ${formatChips(game.pot)}', style: AppText.caption),
              const SizedBox(height: AppSpacing.lg),
              if (onNext != null) ...[
                PremiumButton(label: 'NEXT HAND', icon: Icons.replay, onPressed: onNext),
                const SizedBox(height: AppSpacing.sm),
              ],
              PremiumButton(
                label: 'LEAVE TABLE',
                style: PremiumButtonStyle.secondary,
                onPressed: () {
                  // Leaving clears the game, which unmounts this overlay, so grab the router first.
                  final router = GoRouter.of(context);
                  unawaited(ref.read(gameControllerProvider.notifier).leave());
                  router.go('/');
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
