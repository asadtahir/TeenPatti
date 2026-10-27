import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teen_patti_engine/teen_patti_engine.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/network/connection_status.dart';
import '../../online/online_controller.dart';
import '../../profile/profile.dart';
import '../../stats/stats.dart';
import '../data/game_repository.dart';
import '../data/offline_game_repository.dart';
import 'feedback_service.dart';

class GameUiState {
  const GameUiState({
    this.game,
    this.events = const [],
    this.batch = 0,
    this.deadline,
    this.connection = ConnectionStatus.connected,
    this.localPlayerId = 'you',
    this.failure,
    this.isOnline = false,
  });

  final GameState? game;

  /// Events from the latest update; [batch] increments so listeners fire once per update.
  final List<GameEvent> events;
  final int batch;
  final DateTime? deadline;
  final ConnectionStatus connection;
  final String localPlayerId;
  final AppFailure? failure;
  final bool isOnline;

  LegalActions get legal => game == null
      ? const LegalActions()
      : TeenPattiEngine.legalActions(game!, localPlayerId);

  GameUiState copyWith({
    GameState? game,
    List<GameEvent>? events,
    int? batch,
    Object? deadline = _keep,
    ConnectionStatus? connection,
    Object? failure = _keep,
  }) =>
      GameUiState(
        game: game ?? this.game,
        events: events ?? this.events,
        batch: batch ?? this.batch,
        deadline: identical(deadline, _keep) ? this.deadline : deadline as DateTime?,
        connection: connection ?? this.connection,
        localPlayerId: localPlayerId,
        failure: identical(failure, _keep) ? this.failure : failure as AppFailure?,
        isOnline: isOnline,
      );
}

const Object _keep = Object();

/// Bridges a [GameRepository] (offline or online) to the UI.
class GameController extends Notifier<GameUiState> {
  GameRepository? _repo;
  StreamSubscription<GameUpdate>? _sub;

  @override
  GameUiState build() {
    ref.onDispose(_teardown);
    return const GameUiState();
  }

  Future<void> startOffline({
    required int players,
    required Difficulty difficulty,
  }) async {
    final profile = ref.read(profileProvider);
    final repo = OfflineGameRepository(
      playerName: profile.username,
      playerChips: profile.chips,
      botCount: players - 1,
      difficulty: difficulty,
    );
    await attach(repo, isOnline: false);
    await repo.startGame();
  }

  /// Attach any repository (used for online play too).
  Future<void> attach(GameRepository repo, {required bool isOnline}) async {
    await _teardown();
    _repo = repo;
    state = GameUiState(localPlayerId: repo.localPlayerId, isOnline: isOnline);
    _sub = repo.updates.listen(_onUpdate);
  }

  void _onUpdate(GameUpdate u) {
    state = GameUiState(
      game: u.state,
      events: u.events,
      batch: state.batch + 1,
      deadline: u.turnDeadline,
      connection: u.connection,
      localPlayerId: state.localPlayerId,
      isOnline: state.isOnline,
    );
    ref.read(feedbackServiceProvider).onEvents(u.events, state.localPlayerId);

    if (!state.isOnline) {
      for (final e in u.events) {
        if (e.type == GameEvent.gameEnded) _recordOfflineResult(u.state, e);
      }
    }
  }

  void _recordOfflineResult(GameState s, GameEvent e) {
    final me = s.playerById(state.localPlayerId);
    final won = s.winnerIds.contains(me.id);
    ref.read(profileProvider.notifier).update((p) => p.copyWith(chips: me.chips));
    ref.read(statsProvider.notifier).record(GameRecord(
          at: DateTime.now(),
          won: won,
          pot: s.pot,
          net: (s.payouts[me.id] ?? 0) - me.invested,
          handName: e.data['handName'] as String?,
          players: s.players.length,
        ));
  }

  Future<void> nextHand() async {
    try {
      await _repo?.startGame();
    } catch (e) {
      state = state.copyWith(failure: mapError(e));
    }
  }

  /// Sends a player action. Failures become friendly messages on [GameUiState.failure].
  Future<void> act(GameAction action) async {
    final repo = _repo;
    if (repo == null) return;
    try {
      await repo.send(action);
      if (state.failure != null) state = state.copyWith(failure: null);
    } catch (e) {
      state = state.copyWith(failure: mapError(e is InvalidActionException
          ? const AppFailure(FailureKind.invalidAction)
          : e));
    }
  }

  void clearFailure() => state = state.copyWith(failure: null);

  /// Clears the UI state immediately, then releases the repository.
  Future<void> leave() {
    if (state.isOnline) unawaited(ref.read(onlineProvider.notifier).leaveRoom());
    state = const GameUiState();
    return _teardown();
  }

  Future<void> _teardown() async {
    await _sub?.cancel();
    _sub = null;
    final r = _repo;
    _repo = null;
    await r?.dispose();
  }
}

final gameControllerProvider =
    NotifierProvider<GameController, GameUiState>(GameController.new);
