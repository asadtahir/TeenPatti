# Teen Patti — Phase 1 Plan (Foundation)

Virtual chips only. No real-money flows.

## 1. Folder structure

```
lib/
  core/
    constants/      app_constants.dart
    errors/         app_failure.dart, error_mapper.dart
    network/        connection_state.dart (stub; real client in Phase 6)
    storage/        key_value_store.dart (interface) + shared_prefs impl
    theme/          design tokens: colors, typography, spacing, radii, shadows, durations, card sizes
    utils/          responsive.dart
  features/
    auth/           (Phase 6)
    home/           presentation/home_screen.dart
    lobby/          presentation/lobby_screen.dart (placeholder)
    room/           presentation/room_screen.dart (placeholder)
    game/
      domain/       pure-Dart engine: models, HandEvaluator, betting, rules   (Phase 2)
      ai/           AIEngine, strategies                                       (Phase 3)
      data/         GameRepository, Offline/Online data sources               (Phase 3/7)
      presentation/ table, widgets, animations
    profile/        profile model + provider
    settings/       settings model, controller, screen
  shared/
    widgets/        PremiumButton, ChipBadge, GlassPanel
    animations/     reusable animation primitives (Phase 4)
    components/
  app/              router.dart, app.dart
  main.dart
test/
server/             (Phase 6) backend
```

Rule: `features/game/domain` and `features/game/ai` import **no Flutter**.

## 2. Dependencies (and why)

| Package | Why |
|---|---|
| flutter_riverpod | Requested state management; testable, no BuildContext coupling |
| go_router | Declarative navigation, custom transition pages |
| shared_preferences | Settings/profile persistence in Phase 1; Drift/SQLite added for history in Phase 3 |
| flutter_lints | Analyzer rules |

Deferred until needed: web_socket_channel (P6/7), drift (P3), audioplayers (P4), freezed (not used; plain immutable classes to avoid codegen).

## 3. Architecture

```
Presentation (widgets, Riverpod providers)
        ↓
Game Controller (Notifier: turns intents into engine actions, drives animations)
        ↓
Game Engine (pure Dart, deterministic, same code offline/online/tests)
        ↓
GameRepository (interface)
        ↓
OfflineGameDataSource | OnlineGameDataSource  →  local storage / WebSocket
```

## 4. Game state architecture

Engine is a reducer: `GameState apply(GameState, GameAction)`; seeded RNG injected for tests;
server uses a CSPRNG implementation of the same `RandomSource` interface. State is immutable
(players, currentPlayer, deck, pot, currentBet, round, status, winner, turnDeadline).
Controller emits `GameEvent`s (CardsDealt, BetPlaced, …) that the animation layer consumes, so
logic never waits on animation and animations never mutate state.

## 5. Navigation map

```
/ (Home) ─ /offline (setup) ─ /game ─ /result ─ back to /
        ├ /lobby ─ /room/:code ─ /game ─ /result
        └ /settings
```
Custom fade/scale/slide transition pages via one `AppTransitions` helper.

## 6. Animation architecture

Event-driven: engine events → `AnimationDirector` queues `AnimationCommand`s → reusable widgets
(AnimatedCard, ChipFlight, PotCounter, FloatingBet, WinnerBurst, TurnRing) driven by single
controllers with `RepaintBoundary`. Quality setting (Low–Ultra) and reduce-motion scale durations
and disable particles. Durations come from the design system.

## 7. Offline/online

UI → controller → `GameRepository`. Offline data source runs the engine + AI locally.
Online data source sends intents over WebSocket and applies server-authoritative state
snapshots/events; clients never compute cards, pot or winner. Actions carry idempotency keys.

## 8. Backend / DB plan (Phase 6)

Dart server (shelf + web_socket_channel) reusing the engine package, PostgreSQL via `postgres`;
tables per spec (users … game_history) with FKs and indexes on room code, game_id, user_id;
JWT sessions; per-action log in `game_actions`; rate limiting per connection.

## 9. Roadmap

P1 foundation → P2 engine + tests → P3 offline game + AI → P4 graphics/animation/sound →
P5 lobby → P6 backend → P7 online → P8 security → P9 testing → P10 optimization.
Approval gate after each phase.

## Phase 1 scope

Project, design system, theme, navigation, Riverpod wiring, settings + profile persistence,
placeholder screens (home, offline setup, lobby, room, settings), core model stubs
(Card, Suit, Rank only), error mapping, tests + analyzer + build.
