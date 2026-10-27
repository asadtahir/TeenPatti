import '../actions.dart';
import '../engine.dart';
import '../random_source.dart';
import '../state.dart';
import 'betting_strategy.dart';
import 'hand_strength.dart';
import 'profile.dart';

/// Observed behaviour of one opponent (used on Hard).
class OpponentModel {
  int bets = 0;
  int raises = 0;
  double get aggression => bets == 0 ? 0.2 : raises / bets;
}

/// Chooses an action. Only ever returns actions the engine reports as legal.
class DecisionEngine {
  DecisionEngine(this.profile, this.random)
      : strategy = BettingStrategy(profile);

  final AIProfile profile;
  final RandomSource random;
  final BettingStrategy strategy;

  GameAction decide(
    GameState state,
    String playerId, {
    Map<String, OpponentModel> opponents = const {},
  }) {
    final me = state.playerById(playerId);
    final legal = TeenPattiEngine.legalActions(state, playerId);
    if (!legal.isTurn) throw StateError('Not $playerId\'s turn');

    // Easy mistakes: random but valid move.
    if (random.nextDouble() < strategy.blunderChance) {
      return _randomValid(playerId, legal);
    }

    if (!me.seen) {
      if (_shouldLook(state, me, legal)) return SeeCards(playerId);
      return _blindMove(playerId, legal, me.chips);
    }
    return _seenMove(state, me, legal, opponents);
  }

  bool _shouldLook(GameState s, PlayerState me, LegalActions legal) {
    var p = strategy.seeChance + 0.04 * s.turnNumber;
    // Stakes have climbed: more reason to peek.
    if (s.stake >= s.settings.bootAmount * 4) p += 0.3;
    // Blind bets are getting expensive relative to the stack.
    if (legal.callAmount > me.chips * 0.25) p += 0.4;
    return random.nextDouble() < p.clamp(0.0, 0.95);
  }

  GameAction _blindMove(String id, LegalActions legal, int chips) {
    if (legal.canRaise &&
        legal.raiseAmount * 4 < chips &&
        random.nextDouble() < strategy.blindRaiseChance) {
      return Raise(id);
    }
    if (legal.canCall) return Call(id);
    return legal.canShow ? Show(id) : Fold(id);
  }

  GameAction _seenMove(GameState s, PlayerState me, LegalActions legal,
      Map<String, OpponentModel> opponents) {
    final id = me.id;
    var strength = HandStrengthAnalyzer.strength(me.hand);
    strength += (random.nextDouble() * 2 - 1) * strategy.noise;
    if (random.nextDouble() < strategy.bluffChance) strength = 0.85;
    strength = strength.clamp(0.0, 1.0);

    var foldBelow = strategy.foldBelow;
    var raiseAbove = strategy.raiseAbove;

    if (profile.difficulty == Difficulty.hard) {
      // Opponent analysis: tighten up against aggressive opponents.
      final rivals = [
        for (final p in s.activePlayers)
          if (p.id != id) opponents[p.id]
      ].whereType<OpponentModel>();
      if (rivals.isNotEmpty) {
        final avg =
            rivals.map((o) => o.aggression).reduce((a, b) => a + b) /
                rivals.length;
        foldBelow += (avg - 0.25) * 0.2;
      }
      // Pot odds: a cheap call into a big pot is worth more.
      final cost = legal.canCall ? legal.callAmount : me.chips;
      final potOdds = cost / (s.pot + cost);
      if (potOdds < 0.12) foldBelow -= 0.1;
      // Short stack: protect it.
      if (cost > me.chips * 0.3) raiseAbove += 0.1;
    }

    if (!legal.canCall) {
      // Cannot afford to match: only show (all-in) or fold.
      return legal.canShow && strength > foldBelow ? Show(id) : Fold(id);
    }

    if (legal.canShow) {
      return strength >= foldBelow + 0.1 ? Show(id) : Fold(id);
    }
    if (strength < foldBelow) return Fold(id);
    if (strength > raiseAbove &&
        legal.canRaise &&
        me.chips >= legal.raiseAmount * 2) {
      return Raise(id);
    }
    if (legal.canSideShow && strength > 0.6 && random.nextDouble() < 0.25) {
      return SideShowRequest(id);
    }
    return Call(id);
  }

  /// Reply to a side-show request addressed to [playerId].
  SideShowResponse respondSideShow(GameState state, String playerId) {
    final me = state.playerById(playerId);
    final strength = HandStrengthAnalyzer.strength(me.hand) +
        (random.nextDouble() * 2 - 1) * strategy.noise;
    return SideShowResponse(playerId, accept: strength > 0.5);
  }

  GameAction _randomValid(String id, LegalActions legal) {
    final options = <GameAction>[
      if (legal.canCall) Call(id),
      if (legal.canRaise) Raise(id),
      if (legal.canShow) Show(id),
      Fold(id),
    ];
    return options[random.nextInt(options.length)];
  }
}
