import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/connection_status.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/animations/entrance.dart';
import '../../../shared/widgets/table_background.dart';
import '../../offline/offline_setup_screen.dart';
import 'action_bar.dart';
import 'game_controller.dart';
import 'game_table.dart';

/// Hosts the table. In offline mode it starts the game from the setup screen's choices.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, this.offline = true});
  final bool offline;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.offline) {
      // Start after the first frame so the table is already listening for the deal.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final setup = ref.read(offlineSetupProvider);
        ref
            .read(gameControllerProvider.notifier)
            .startOffline(players: setup.players, difficulty: setup.difficulty);
      });
    }
  }

  void _leave() {
    unawaited(ref.read(gameControllerProvider.notifier).leave());
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GameUiState>(gameControllerProvider, (prev, next) {
      final f = next.failure;
      if (f != null && f != prev?.failure) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(f.message),
              duration: const Duration(seconds: 2),
            ),
          );
        ref.read(gameControllerProvider.notifier).clearFailure();
      }
    });
    final conn = ref.watch(gameControllerProvider.select((s) => s.connection));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: TableBackground(
          dark: true,
          child: Column(
            children: [
              Entrance(
                offset: const Offset(0, -24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Leave table',
                        icon: const Icon(Icons.close),
                        onPressed: _leave,
                      ),
                      const Spacer(),
                      if (conn != ConnectionStatus.connected)
                        _ConnectionPill(conn),
                    ],
                  ),
                ),
              ),
              const Expanded(child: GameTable()),
              const Entrance(
                delay: Duration(milliseconds: 450),
                offset: Offset(0, 70),
                curve: Curves.easeOutBack,
                child: ActionBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill(this.status);
  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      ConnectionStatus.reconnecting => 'Reconnecting...',
      ConnectionStatus.connecting => 'Connecting...',
      ConnectionStatus.offline => 'Offline',
      ConnectionStatus.connected => 'Connected',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
