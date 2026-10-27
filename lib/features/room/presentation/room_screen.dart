import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/connection_status.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/widgets/chip_badge.dart';
import '../../../shared/widgets/premium_button.dart';
import '../../../shared/widgets/screen_scaffold.dart';
import '../../game/presentation/game_controller.dart';
import '../../online/online_controller.dart';

/// Waiting room. The host starts the game; everyone moves to the table when it begins.
class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key, required this.code});
  final String code;

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  bool _openedGame = false;

  void _maybeOpenGame(OnlineState s) {
    final room = s.room;
    if (_openedGame || room == null || !room.playing) return;
    final repo = ref.read(onlineProvider.notifier).repository;
    if (repo == null) return;
    _openedGame = true;
    unawaited(ref.read(gameControllerProvider.notifier).attach(repo, isOnline: true).then((_) {
      if (mounted) context.push('/online-game');
    }));
  }

  Future<void> _leave() async {
    unawaited(ref.read(onlineProvider.notifier).leaveRoom());
    if (mounted) context.go('/');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeOpenGame(ref.read(onlineProvider));
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<OnlineState>(onlineProvider, (prev, next) {
      _maybeOpenGame(next);
      // Back to the waiting room after a hand: allow opening the next game.
      if (prev?.room?.playing == true && next.room?.playing == false) _openedGame = false;
      if (prev?.room != null && next.room == null && mounted) context.go('/');
      final f = next.failure;
      if (f != null && f != prev?.failure) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(onlineErrorText(f))));
        ref.read(onlineProvider.notifier).clearFailure();
      }
    });

    final online = ref.watch(onlineProvider);
    final room = online.room;
    final code = room?.code ?? widget.code;

    return ScreenScaffold(
      title: 'Room',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (online.connection != ConnectionStatus.connected)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                online.connection == ConnectionStatus.reconnecting ? 'Reconnecting...' : 'Connecting...',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700),
              ),
            ),
          const Text('Room Code', textAlign: TextAlign.center, style: AppText.caption),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: 'Join my Teen Patti table! Room code: $code'));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Invite copied. Paste it to a friend.')));
            },
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(code, style: AppText.display.copyWith(color: AppColors.gold)),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.copy, size: 18, color: AppColors.textMuted),
            ]),
          ),
          const Text('Tap to copy an invite', textAlign: TextAlign.center, style: AppText.caption),
          const SizedBox(height: AppSpacing.lg),
          const Text('Players', style: AppText.title),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView(children: [
              for (final p in room?.players ?? const <RoomPlayer>[])
                ListTile(
                  leading: Icon(p.connected ? Icons.person : Icons.person_off,
                      color: p.connected ? AppColors.gold : AppColors.textMuted),
                  title: Text(p.id == online.userId ? '${p.name} (you)' : p.name),
                  subtitle: Text(p.connected ? formatChips(p.chips) : 'Reconnecting...'),
                  trailing: p.host ? const Icon(Icons.workspace_premium, color: AppColors.gold) : null,
                ),
            ]),
          ),
          Text(
            room == null
                ? 'Joining...'
                : (room.players.length < room.maxPlayers
                    ? 'Waiting for players... (${room.players.length}/${room.maxPlayers})'
                    : 'Room is full'),
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          if (online.isHost)
            PremiumButton(
              label: 'START GAME',
              icon: Icons.play_arrow_rounded,
              onPressed: (room?.players.length ?? 0) >= 2 && !online.busy
                  ? () => ref.read(onlineProvider.notifier).startGame()
                  : null,
            )
          else
            const Text('Waiting for the host to start', textAlign: TextAlign.center, style: AppText.caption),
          const SizedBox(height: AppSpacing.sm),
          PremiumButton(label: 'LEAVE ROOM', style: PremiumButtonStyle.secondary, onPressed: _leave),
        ],
      ),
    );
  }
}
