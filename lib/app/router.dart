import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/design_tokens.dart';
import '../features/game/presentation/game_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/lobby/presentation/lobby_screen.dart';
import '../features/offline/offline_setup_screen.dart';
import '../features/room/presentation/room_screen.dart';
import '../features/settings/settings_screen.dart';

/// Shared fade + slight scale transition used by every route.
CustomTransitionPage<void> _page(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppDurations.pageTransition,
    reverseTransitionDuration: AppDurations.pageTransition,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
            scale: Tween(begin: 0.97, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

GoRouter buildRouter() => GoRouter(
      routes: [
        GoRoute(path: '/', pageBuilder: (c, s) => _page(s, const HomeScreen())),
        GoRoute(
            path: '/offline',
            pageBuilder: (c, s) => _page(s, const OfflineSetupScreen())),
        GoRoute(
            path: '/lobby',
            pageBuilder: (c, s) => _page(s, const LobbyScreen())),
        GoRoute(
            path: '/room/:code',
            pageBuilder: (c, s) =>
                _page(s, RoomScreen(code: s.pathParameters['code']!))),
        GoRoute(
            path: '/game', pageBuilder: (c, s) => _page(s, const GameScreen())),
        GoRoute(
            path: '/online-game',
            pageBuilder: (c, s) => _page(s, const GameScreen(offline: false))),
        GoRoute(
            path: '/settings',
            pageBuilder: (c, s) => _page(s, const SettingsScreen())),
      ],
    );
