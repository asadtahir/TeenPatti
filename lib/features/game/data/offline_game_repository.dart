import 'dart:async';

import 'package:teen_patti_engine/teen_patti_engine.dart';

import 'game_repository.dart';

/// Runs the engine and AI entirely on-device. Never touches the network.
class OfflineGameRepository implements GameRepository {
  OfflineGameRepository({
    required this.playerName,
    required int playerChips,
    required this.botCount,
    required this.difficulty,
    this.settings = const GameSettings(),
    RandomSource? random,
    this.botThinkTime = const Duration(milliseconds: 1100),
    this.refillChips = 10000,
  })  : _random = random ?? SecureRandomSource(),
        assert(botCount >= 2 && botCount <= 5) {
    _chips[localPlayerId] = playerChips;
    _names[localPlayerId] = playerName;
    for (var i = 1; i <= botCount; i++) {
      _chips['bot$i'] = refillChips;
      _names['bot$i'] = _botNames[(i - 1) % _botNames.length];
    }
    _ai = AIEngine.forBots(
        [for (var i = 1; i <= botCount; i++) 'bot$i'], difficulty, _random);
  }

  static const _botNames = ['Raj', 'Simran', 'Vikram', 'Neha', 'Arjun'];

  final String playerName;
  final int botCount;
  final Difficulty difficulty;
  final GameSettings settings;
  final Duration botThinkTime;
  final int refillChips;
  final RandomSource _random;

  @override
  final String localPlayerId = 'you';

  final _chips = <String, int>{};
  final _names = <String, String>{};
  late final AIEngine _ai;
  final _controller = StreamController<GameUpdate>.broadcast();

  GameState? _state;
  int _dealer = -1;
  Timer? _timer;
  DateTime? _deadline;
  bool _disposed = false;

  @override
  Stream<GameUpdate> get updates => _controller.stream;

  List<String> get _seatOrder => [localPlayerId, for (var i = 1; i <= botCount; i++) 'bot$i'];

  @override
  Future<void> startGame() async {
    _timer?.cancel();
    // Bots rebuy when broke; the human is topped up so offline play never dead-ends.
    for (final id in _seatOrder) {
      if ((_chips[id] ?? 0) < settings.bootAmount) _chips[id] = refillChips;
    }
    _dealer = (_dealer + 1) % _seatOrder.length;
    final result = TeenPattiEngine.startGame(
      players: [
        for (final id in _seatOrder)
          PlayerState(id: id, name: _names[id]!, chips: _chips[id]!, isBot: id != localPlayerId),
      ],
      settings: settings,
      random: _random,
      dealerIndex: _dealer,
    );
    _publish(result.state, result.events);
  }

  @override
  Future<void> send(GameAction action) async {
    if (action.playerId != localPlayerId) {
      throw const InvalidActionException('Not your seat');
    }
    _applyAction(action);
  }

  void _applyAction(GameAction action) {
    final s = _state;
    if (s == null) throw const InvalidActionException('No game running');
    final result = TeenPattiEngine.apply(s, action);
    _ai.observe(result.events);
    _publish(result.state, result.events);
  }

  void _publish(GameState state, List<GameEvent> events) {
    _state = state;
    _timer?.cancel();
    _deadline = null;

    if (state.isFinished) {
      for (final p in state.players) {
        _chips[p.id] = p.chips;
      }
    } else {
      _schedule(state);
    }
    if (!_controller.isClosed) {
      _controller.add(GameUpdate(
        state: state.redactedFor(localPlayerId),
        events: events,
        turnDeadline: _deadline,
      ));
    }
  }

  void _schedule(GameState s) {
    final pending = s.pendingSideShow;
    if (pending != null) {
      if (_ai.controls(pending.responderId)) {
        _timer = Timer(botThinkTime, () => _guard(() {
              _applyAction(_ai.sideShowReply(s, pending.responderId));
            }));
      } else {
        // Human must answer; silence counts as a decline.
        _setDeadline(const Duration(seconds: 10));
        _timer = Timer(const Duration(seconds: 10), () => _guard(() {
              _applyAction(SideShowResponse(localPlayerId, accept: false));
            }));
      }
      return;
    }

    final current = s.currentPlayer;
    if (_ai.controls(current.id)) {
      _timer = Timer(botThinkTime, () => _guard(() {
            _applyAction(_ai.nextAction(s, current.id));
          }));
    } else {
      final limit = Duration(seconds: settings.turnSeconds);
      _setDeadline(limit);
      _timer = Timer(limit, () => _guard(() {
            // Turn timer expired: default action is fold.
            _applyAction(Fold(localPlayerId));
          }));
    }
  }

  void _setDeadline(Duration d) => _deadline = DateTime.now().add(d);

  void _guard(void Function() body) {
    if (_disposed) return;
    try {
      body();
    } on InvalidActionException {
      // A stale timer fired after state moved on; ignore.
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    // Not awaited: the returned future can stay pending once listeners have cancelled.
    unawaited(_controller.close());
  }
}
