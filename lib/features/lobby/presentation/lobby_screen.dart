import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/connection_status.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/animations/entrance.dart';
import '../../../shared/widgets/chip_badge.dart';
import '../../../shared/widgets/premium_button.dart';
import '../../../shared/widgets/screen_scaffold.dart';
import '../../online/online_controller.dart';
import '../../stats/stats.dart';

class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({super.key});

  Future<void> _enter(
    BuildContext context,
    WidgetRef ref,
    Future<String?> action,
  ) async {
    final code = await action;
    if (!context.mounted) return;
    if (code != null && code.isNotEmpty) {
      context.push('/room/$code');
    } else {
      final f = ref.read(onlineProvider).failure;
      if (f != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(onlineErrorText(f))));
      }
    }
  }

  Future<void> _askCode(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Join Room'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 7,
          decoration: const InputDecoration(hintText: 'ABCD123'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty || !context.mounted) return;
    await _enter(
      context,
      ref,
      ref.read(onlineProvider.notifier).joinRoom(code),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineProvider);
    final ctrl = ref.read(onlineProvider.notifier);
    final history = ref.watch(statsProvider).history.take(5).toList();
    final busy =
        online.busy || online.connection == ConnectionStatus.connecting;

    return ScreenScaffold(
      title: 'Lobby',
      child: ListView(
        children: staggered(
          [
            const Text('Quick Play', style: AppText.title),
            const SizedBox(height: AppSpacing.xs),
            const Text('Matched with random players', style: AppText.caption),
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
                  Entrance(
                    delay: Duration(milliseconds: 300 + 70 * n),
                    offset: Offset.zero,
                    scaleFrom: 0.6,
                    curve: Curves.easeOutBack,
                    child: ActionChip(
                      avatar: const Icon(
                        Icons.groups,
                        size: 18,
                        color: AppColors.gold,
                      ),
                      label: Text('$n Players'),
                      onPressed: busy
                          ? null
                          : () => _enter(context, ref, ctrl.quickPlay(n)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Private Room', style: AppText.title),
            const SizedBox(height: AppSpacing.sm),
            PremiumButton(
              label: 'CREATE ROOM',
              icon: Icons.add,
              onPressed: busy
                  ? null
                  : () => _enter(context, ref, ctrl.createRoom(maxPlayers: 6)),
            ),
            const SizedBox(height: AppSpacing.sm),
            PremiumButton(
              label: 'JOIN ROOM',
              icon: Icons.login,
              style: PremiumButtonStyle.secondary,
              onPressed: busy ? null : () => _askCode(context, ref),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Friends', style: AppText.title),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Create a private room and share its code to play with friends.',
              style: AppText.caption,
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Recent Games', style: AppText.title),
            const SizedBox(height: AppSpacing.sm),
            if (history.isEmpty)
              const Text('No games yet.', style: AppText.caption)
            else
              for (final g in history)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    g.won ? Icons.emoji_events : Icons.close,
                    color: g.won ? AppColors.gold : AppColors.textMuted,
                  ),
                  title: Text(
                    g.won ? 'Won ${g.handName ?? ''}'.trim() : 'Lost',
                  ),
                  subtitle: Text(
                    '${g.players} players  ·  pot ${formatChips(g.pot)}',
                  ),
                  trailing: Text(
                    g.net >= 0
                        ? '+${formatChips(g.net)}'
                        : '-${formatChips(-g.net)}',
                    style: TextStyle(
                      color: g.net >= 0 ? AppColors.success : AppColors.crimson,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.md),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
              ),
          ],
          start: const Duration(milliseconds: 120),
          step: const Duration(milliseconds: 60),
        ),
      ),
    );
  }
}
