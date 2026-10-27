import 'dart:async';

import 'package:teen_patti_engine/teen_patti_engine.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/connection_status.dart';
import '../../../core/network/online_session.dart';
import 'game_repository.dart';

/// Thin client for the authoritative server. It never computes cards, pots or winners:
/// it renders the redacted state the server sends and submits intents.
class OnlineGameRepository implements GameRepository {
  OnlineGameRepository(this.session, {this.ackTimeout = const Duration(seconds: 3), this.maxAttempts = 4}) {
    _sub = session.messages.listen(_onMessage);
    _statusSub = session.status.listen(_onStatus);
  }

  final OnlineSession session;
  final Duration ackTimeout;
  final int maxAttempts;

  late final StreamSubscription<Json> _sub;
  late final StreamSubscription<ConnectionStatus> _statusSub;
  final _controller = StreamController<GameUpdate>.broadcast();
  /// Latest update (any kind) and latest real game message (for replay with its events).
  GameUpdate? _last;
  GameUpdate? _lastGame;
  int _lastSeq = -1;
  DateTime? _deadline;
  int _actionSeq = 0;
  final _ackWaiters = <String, Completer<Json>>{};

  @override
  String get localPlayerId => session.userId ?? '';

  /// Replays the latest state to new listeners so a screen opened late still gets the deal.
  @override
  Stream<GameUpdate> get updates => Stream<GameUpdate>.multi((c) {
        final g = _lastGame;
        if (g != null) {
          c.add(GameUpdate(
              state: _last!.state, events: g.events, turnDeadline: _deadline, connection: session.currentStatus));
        }
        final sub = _controller.stream.listen(c.add);
        c.onCancel = sub.cancel;
      });

  /// The host asks the server for the next hand.
  @override
  Future<void> startGame() async {
    final r = await session.request({'type': 'START_GAME'});
    if (r['ok'] != true) throw AppFailure(FailureKind.invalidAction, cause: r['error']);
  }

  @override
  Future<void> send(GameAction action) async {
    // One id per intent: resending after a reconnect can never apply twice.
    final actionId = '${DateTime.now().microsecondsSinceEpoch}-${_actionSeq++}';
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final waiter = _ackWaiters.putIfAbsent(actionId, Completer<Json>.new);
      if (session.send({'type': 'ACTION', 'actionId': actionId, 'action': action.toJson()})) {
        try {
          final ack = await waiter.future.timeout(ackTimeout);
          _ackWaiters.remove(actionId);
          if (ack['ok'] == true) return;
          throw InvalidActionException('${ack['error']}');
        } on TimeoutException {
          // fall through and retry with the same id
        }
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    _ackWaiters.remove(actionId);
    throw const AppFailure(FailureKind.connectionLost);
  }

  void _onMessage(Json msg) {
    switch (msg['type']) {
      case 'ACK':
        final c = _ackWaiters[msg['actionId']];
        if (c != null && !c.isCompleted) c.complete(msg);
      case 'GAME_STATE':
        final seq = msg['seq'] as int;
        if (seq < _lastSeq) return; // stale, out of order
        _lastSeq = seq;
        final state = GameState.fromJson((msg['state'] as Map).cast<String, Object?>());
        _deadline = _toLocal(msg);
        final update = GameUpdate(
          state: state,
          events: [for (final e in (msg['events'] as List)) GameEvent.fromJson((e as Map).cast<String, Object?>())],
          turnDeadline: _deadline,
          connection: session.currentStatus,
        );
        _lastGame = update;
        _emit(update);
      case 'DEADLINE':
        final last = _last;
        if (last == null || (msg['seq'] as int) < _lastSeq) return;
        _deadline = _toLocal(msg);
        _emit(GameUpdate(state: last.state, turnDeadline: _deadline, connection: session.currentStatus));
    }
  }

  /// Convert the server's deadline to local time, correcting for clock skew.
  DateTime? _toLocal(Json msg) {
    final ms = msg['deadlineMs'] as int?;
    if (ms == null) return null;
    final skew = (msg['serverTime'] as int) - DateTime.now().millisecondsSinceEpoch;
    return DateTime.fromMillisecondsSinceEpoch(ms - skew);
  }

  void _onStatus(ConnectionStatus s) {
    final last = _last;
    if (last == null) return;
    _emit(GameUpdate(state: last.state, turnDeadline: _deadline, connection: s));
  }

  void _emit(GameUpdate u) {
    _last = u;
    if (!_controller.isClosed) _controller.add(u);
  }

  /// Releases this repository only; the shared [OnlineSession] stays open.
  @override
  Future<void> dispose() async {
    await _sub.cancel();
    await _statusSub.cancel();
    unawaited(_controller.close());
  }
}
