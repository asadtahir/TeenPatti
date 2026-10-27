import '../actions.dart';
import '../events.dart';
import '../random_source.dart';
import '../state.dart';
import 'decision_engine.dart';
import 'profile.dart';

/// One bot at the table.
class AIPlayer {
  AIPlayer(this.id, this.profile, RandomSource random)
      : _decisions = DecisionEngine(profile, random);

  final String id;
  final AIProfile profile;
  final DecisionEngine _decisions;
  final Map<String, OpponentModel> _opponents = {};

  void observe(List<GameEvent> events) {
    for (final e in events) {
      if (e.type != GameEvent.playerBet) continue;
      final pid = e.playerId;
      if (pid == null || pid == id) continue;
      final m = _opponents.putIfAbsent(pid, OpponentModel.new);
      m.bets++;
      if (e.data['kind'] == 'RAISE') m.raises++;
    }
  }

  GameAction nextAction(GameState state) =>
      _decisions.decide(state, id, opponents: _opponents);

  SideShowResponse replyToSideShow(GameState state) =>
      _decisions.respondSideShow(state, id);
}

/// Owns every bot and tells each what to do when it is their move.
class AIEngine {
  AIEngine(this._players);

  /// Build bots for the given ids with personalities spread across the table.
  factory AIEngine.forBots(
    List<String> botIds,
    Difficulty difficulty,
    RandomSource random,
  ) {
    const order = Personality.values;
    return AIEngine({
      for (var i = 0; i < botIds.length; i++)
        botIds[i]: AIPlayer(botIds[i],
            AIProfile(difficulty, order[random.nextInt(order.length)]), random),
    });
  }

  final Map<String, AIPlayer> _players;

  bool controls(String playerId) => _players.containsKey(playerId);

  AIProfile? profileOf(String playerId) => _players[playerId]?.profile;

  void observe(List<GameEvent> events) {
    for (final p in _players.values) {
      p.observe(events);
    }
  }

  GameAction nextAction(GameState state, String playerId) =>
      _players[playerId]!.nextAction(state);

  SideShowResponse sideShowReply(GameState state, String playerId) =>
      _players[playerId]!.replyToSideShow(state);
}
