import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/design_tokens.dart';
import '../features/game/presentation/game_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/lobby/presentation/lobby_screen.dart';
import '../features/offline/offline_setup_screen.dart';
import '../features/room/presentation/room_screen.dart';
import '../features/rules/rules_screen.dart';
import '../features/settings/settings_screen.dart';

enum _Motion {
  /// Menu pages slide in from the right while the page underneath drifts left and dims.
  slide,

  /// The table zooms up out of the dark.
  zoom,
}

/// Route transition: [_Motion.slide] for menu pages, [_Motion.zoom] for the game table.
CustomTransitionPage<void> _page(
  GoRouterState state,
  Widget child, [
  _Motion motion = _Motion.slide,
]) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: motion == _Motion.zoom
        ? const Duration(milliseconds: 450)
        : AppDurations.pageTransition,
    reverseTransitionDuration: AppDurations.pageTransition,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final under = CurvedAnimation(
        parent: secondary,
        curve: Curves.easeOutCubic,
      );
      Widget page;
      if (motion == _Motion.zoom) {
        page = FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.9, end: 1.0).animate(curved),
            child: child,
          ),
        );
      } else {
        page = FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0.12, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      }
      // When another page opens on top of this one, drift away and dim.
      return SlideTransition(
        position: Tween(
          begin: Offset.zero,
          end: const Offset(-0.06, 0),
        ).animate(under),
        child: FadeTransition(
          opacity: Tween(begin: 1.0, end: 0.6).animate(under),
          child: page,
        ),
      );
    },
  );
}

GoRouter buildRouter() => GoRouter(
  routes: [
    GoRoute(path: '/', pageBuilder: (c, s) => _page(s, const HomeScreen())),
    GoRoute(
      path: '/offline',
      pageBuilder: (c, s) => _page(s, const OfflineSetupScreen()),
    ),
    GoRoute(
      path: '/lobby',
      pageBuilder: (c, s) => _page(s, const LobbyScreen()),
    ),
    GoRoute(
      path: '/room/:code',
      pageBuilder: (c, s) =>
          _page(s, RoomScreen(code: s.pathParameters['code']!)),
    ),
    GoRoute(
      path: '/game',
      pageBuilder: (c, s) => _page(s, const GameScreen(), _Motion.zoom),
    ),
    GoRoute(
      path: '/online-game',
      pageBuilder: (c, s) =>
          _page(s, const GameScreen(offline: false), _Motion.zoom),
    ),
    GoRoute(
      path: '/rules',
      pageBuilder: (c, s) => _page(s, const RulesScreen()),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (c, s) => _page(s, const SettingsScreen()),
    ),
  ],
);
