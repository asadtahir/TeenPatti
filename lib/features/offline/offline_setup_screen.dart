import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/design_tokens.dart';
import '../../shared/animations/entrance.dart';
import '../../shared/widgets/premium_button.dart';
import '../../shared/widgets/screen_scaffold.dart';

import 'package:teen_patti_engine/teen_patti_engine.dart' show Difficulty;

class OfflineSetup {
  const OfflineSetup({this.players = 4, this.difficulty = Difficulty.medium});
  final int players;
  final Difficulty difficulty;

  OfflineSetup copyWith({int? players, Difficulty? difficulty}) => OfflineSetup(
    players: players ?? this.players,
    difficulty: difficulty ?? this.difficulty,
  );
}

class OfflineSetupController extends Notifier<OfflineSetup> {
  @override
  OfflineSetup build() => const OfflineSetup();

  void setPlayers(int n) => state = state.copyWith(players: n);
  void setDifficulty(Difficulty d) => state = state.copyWith(difficulty: d);
}

final offlineSetupProvider =
    NotifierProvider<OfflineSetupController, OfflineSetup>(
      OfflineSetupController.new,
    );

class OfflineSetupScreen extends ConsumerWidget {
  const OfflineSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(offlineSetupProvider);
    final ctrl = ref.read(offlineSetupProvider.notifier);
    return ScreenScaffold(
      title: 'Offline Mode',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: staggered([
            const Text('Choose Players', style: AppText.title),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (
                  var n = AppConstants.minPlayers;
                  n <= AppConstants.maxPlayers;
                  n++
                )
                  _PopChip(
                    label: '$n Players',
                    selected: setup.players == n,
                    onSelected: () => ctrl.setPlayers(n),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Difficulty', style: AppText.title),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final d in Difficulty.values)
                  _PopChip(
                    label: d.name[0].toUpperCase() + d.name.substring(1),
                    selected: setup.difficulty == d,
                    onSelected: () => ctrl.setDifficulty(d),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AnimatedSwitcher(
              duration: AppDurations.normal,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.4),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                _describe(setup.difficulty),
                key: ValueKey(setup.difficulty),
                style: AppText.caption,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PremiumButton(
              label: 'START GAME',
              icon: Icons.play_arrow_rounded,
              onPressed: () => context.push('/game'),
            ),
          ], step: const Duration(milliseconds: 90)),
        ),
      ),
    );
  }
}

String _describe(Difficulty d) => switch (d) {
  Difficulty.easy =>
    'Bots play loosely, bluff rarely and misjudge their hands.',
  Difficulty.medium =>
    'Bots weigh hand strength against the pot and fold weak hands.',
  Difficulty.hard =>
    'Bots track how you bet, bluff smartly and punish loose play.',
};

/// A choice chip that gives a little bounce when it becomes selected.
class _PopChip extends StatelessWidget {
  const _PopChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.07 : 1,
      duration: AppDurations.normal,
      curve: Curves.easeOutBack,
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
