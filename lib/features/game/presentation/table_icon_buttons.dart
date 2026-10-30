import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/design_tokens.dart';
import '../../settings/settings_controller.dart';
import 'feedback_service.dart';

/// Round glass button used in the table's top bar.
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = AppColors.gold,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black45,
        shape: CircleBorder(side: BorderSide(color: color.withValues(alpha: 0.5))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 22, color: color),
          ),
        ),
      ),
    );
  }
}

/// Switches sound effects on or off without leaving the table.
class SoundToggleButton extends ConsumerWidget {
  const SoundToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(settingsProvider.select((s) => s.sound));
    return _RoundIconButton(
      icon: on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
      tooltip: on ? 'Sound on. Tap to mute' : 'Sound off. Tap to unmute',
      color: on ? AppColors.gold : AppColors.textMuted,
      onTap: () {
        ref.read(settingsProvider.notifier).update((s) => s.copyWith(sound: !on));
        // Confirm with a sound when switching on (the settings flag is already true here).
        if (!on) ref.read(feedbackServiceProvider).play(SoundEffect.chip);
      },
    );
  }
}

/// Opens the rules page on top of the table; its back button returns to the game.
class RulesButton extends StatelessWidget {
  const RulesButton({super.key});

  @override
  Widget build(BuildContext context) {
    return _RoundIconButton(
      icon: Icons.menu_book_outlined,
      tooltip: 'How to play',
      onTap: () => context.push('/rules'),
    );
  }
}
