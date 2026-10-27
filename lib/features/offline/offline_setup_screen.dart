import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/design_tokens.dart';
import '../../shared/widgets/premium_button.dart';
import '../../shared/widgets/screen_scaffold.dart';
import 'package:teen_patti_engine/teen_patti_engine.dart' show Difficulty;

class OfflineSetup {
  const OfflineSetup({this.players = 4, this.difficulty = Difficulty.medium});
  final int players;
  final Difficulty difficulty;

  OfflineSetup copyWith({int? players, Difficulty? difficulty}) => OfflineSetup(
      players: players ?? this.players,
      difficulty: difficulty ?? this.difficulty);
}

class OfflineSetupController extends Notifier<OfflineSetup> {
  @override
  OfflineSetup build() => const OfflineSetup();

  void setPlayers(int n) => state = state.copyWith(players: n);
  void setDifficulty(Difficulty d) => state = state.copyWith(difficulty: d);
}

final offlineSetupProvider =
    NotifierProvider<OfflineSetupController, OfflineSetup>(
        OfflineSetupController.new);

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
          children: [
            const Text('Choose Players', style: AppText.title),
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
              for (var n = AppConstants.minPlayers;
                  n <= AppConstants.maxPlayers;
                  n++)
                ChoiceChip(
                  label: Text('$n Players'),
                  selected: setup.players == n,
                  onSelected: (_) => ctrl.setPlayers(n),
                ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            const Text('Difficulty', style: AppText.title),
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.sm, children: [
              for (final d in Difficulty.values)
                ChoiceChip(
                  label: Text(d.name[0].toUpperCase() + d.name.substring(1)),
                  selected: setup.difficulty == d,
                  onSelected: (_) => ctrl.setDifficulty(d),
                ),
            ]),
            const SizedBox(height: AppSpacing.xl),
            PremiumButton(
              label: 'START GAME',
              icon: Icons.play_arrow_rounded,
              onPressed: () => context.push('/game'),
            ),
          ],
        ),
      ),
    );
  }
}
