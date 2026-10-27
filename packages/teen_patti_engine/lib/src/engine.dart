import 'actions.dart';
import 'card.dart';
import 'deck.dart';
import 'events.dart';
import 'hand_evaluator.dart';
import 'random_source.dart';
import 'settings.dart';
import 'state.dart';

class InvalidActionException implements Exception {
  const InvalidActionException(this.message);
  final String message;
  @override
  String toString() => 'InvalidActionException: $message';
}

class ApplyResult {
  const ApplyResult(this.state, this.events);
  final GameState state;
  final List<GameEvent> events;
}

/// What a player may do right now. Used by UI, AI and server validation.
class LegalActions {
  const LegalActions({
    this.isTurn = false,
    this.canSee = false,
    this.canCall = false,
    this.callAmount = 0,
    this.canRaise = false,
    this.raiseAmount = 0,
    this.newStake = 0,
    this.canFold = false,
    this.canShow = false,
    this.showAmount = 0,
    this.canSideShow = false,
    this.canRespondSideShow = false,
  });

  final bool isTurn;
  final bool canSee;
  final bool canCall;
  final int callAmount;
  final bool canRaise;
  final int raiseAmount;
  final int newStake;
  final bool canFold;
  final bool canShow;
  final int showAmount;
  final bool canSideShow;
  final bool canRespondSideShow;
}

/// Pure, deterministic Teen Patti rules. Immutable state in, new state out.
abstract final class TeenPattiEngine {
  static ApplyResult startGame({
    required List<PlayerState> players,
    required GameSettings settings,
    required RandomSource random,
    int dealerIndex = 0,
  }) {
    final n = players.length;
    if (n < 2 || n > 6) {
      throw const InvalidActionException('A table needs 2 to 6 players');
    }
    if (players.map((p) => p.id).toSet().length != n) {
      throw const InvalidActionException('Duplicate player ids');
    }
    for (final p in players) {
      if (p.chips < settings.bootAmount) {
        throw InvalidActionException('${p.name} cannot afford the boot');
      }
    }

    final deck = Deck.shuffled(random);
    final hands = List.generate(n, (_) => <PlayingCard>[]);
    final dealOrder = <String>[];
    for (var round = 0; round < 3; round++) {
      for (var k = 1; k <= n; k++) {
        final i = (dealerIndex + k) % n;
        hands[i].add(deck.draw());
        dealOrder.add(players[i].id);
      }
    }

    final seated = [
      for (var i = 0; i < n; i++)
        PlayerState(
          id: players[i].id,
          name: players[i].name,
          isBot: players[i].isBot,
          chips: players[i].chips - settings.bootAmount,
          invested: settings.bootAmount,
          hand: hands[i],
        ),
    ];
    final first = (dealerIndex + 1) % n;
    final state = GameState(
      players: seated,
      settings: settings,
      dealerIndex: dealerIndex,
      currentIndex: first,
      pot: settings.bootAmount * n,
      stake: settings.bootAmount,
      status: GameStatus.inProgress,
    );
    return ApplyResult(state, [
      GameEvent(GameEvent.gameStarted, {'dealerId': seated[dealerIndex].id}),
      GameEvent(GameEvent.bootCollected,
          {'amount': settings.bootAmount, 'pot': state.pot}),
      GameEvent(GameEvent.cardsDealt, {'order': dealOrder}),
      GameEvent(GameEvent.turnChanged, {'playerId': seated[first].id}),
    ]);
  }

  static int _callAmount(GameState s, PlayerState p) =>
      p.seen ? s.stake * 2 : s.stake;

  static LegalActions legalActions(GameState s, String playerId) {
    if (s.status != GameStatus.inProgress) return const LegalActions();
    final i = s.indexOf(playerId);
    if (i < 0) return const LegalActions();
    final p = s.players[i];
    if (p.folded) return const LegalActions();

    final pending = s.pendingSideShow;
    if (pending != null) {
      return LegalActions(canRespondSideShow: pending.responderId == playerId);
    }

    final isTurn = s.currentIndex == i;
    final canSee = !p.seen;
    if (!isTurn) return LegalActions(canSee: canSee);

    final call = _callAmount(s, p);
    final active = s.activePlayers.length;
    final newStake = (s.stake * 2).clamp(0, s.settings.maxStake);
    final raise = p.seen ? newStake * 2 : newStake;
    final canRaise = newStake > s.stake && p.chips >= raise;
    final prev = _previousActive(s, i);

    return LegalActions(
      isTurn: true,
      canSee: canSee,
      canCall: p.chips >= call,
      callAmount: call,
      canRaise: canRaise,
      raiseAmount: raise,
      newStake: newStake,
      canFold: true,
      canShow: active == 2,
      showAmount: call < p.chips ? call : p.chips,
      canSideShow: active >= 3 &&
          p.seen &&
          s.players[prev].seen &&
          p.chips >= call,
    );
  }

  /// Who a side-show request from [index] would be directed at.
  static String? sideShowTarget(GameState s, String playerId) {
    final i = s.indexOf(playerId);
    if (i < 0) return null;
    return s.players[_previousActive(s, i)].id;
  }

  static int _previousActive(GameState s, int from) {
    final n = s.players.length;
    var i = from;
    do {
      i = (i - 1 + n) % n;
    } while (s.players[i].folded);
    return i;
  }

  static int _nextActive(GameState s, int from) {
    final n = s.players.length;
    var i = from;
    do {
      i = (i + 1) % n;
    } while (s.players[i].folded);
    return i;
  }

  static ApplyResult apply(GameState s, GameAction action) {
    if (s.status != GameStatus.inProgress) {
      throw const InvalidActionException('Game is not in progress');
    }
    final i = s.indexOf(action.playerId);
    if (i < 0) throw const InvalidActionException('Unknown player');
    final p = s.players[i];
    if (p.folded) throw const InvalidActionException('Player has folded');

    final pending = s.pendingSideShow;
    if (pending != null) {
      if (action is! SideShowResponse || pending.responderId != p.id) {
        throw const InvalidActionException('Waiting for side show reply');
      }
      return _resolveSideShow(s, pending, action.accept);
    }
    if (action is SideShowResponse) {
      throw const InvalidActionException('No side show pending');
    }

    if (action is SeeCards) {
      if (p.seen) throw const InvalidActionException('Already seen');
      return ApplyResult(_setPlayer(s, i, p.copyWith(seen: true)),
          [GameEvent(GameEvent.playerSeen, {'playerId': p.id})]);
    }

    if (s.currentIndex != i) {
      throw const InvalidActionException('Not your turn');
    }

    return switch (action) {
      Call() => _bet(s, i, 'CALL', raise: false),
      Raise() => _bet(s, i, 'RAISE', raise: true),
      Fold() => _fold(s, i),
      Show() => _show(s, i),
      SideShowRequest() => _requestSideShow(s, i),
      _ => throw const InvalidActionException('Unsupported action'),
    };
  }

  static GameState _setPlayer(GameState s, int i, PlayerState p) {
    final list = List.of(s.players)..[i] = p;
    return s.copyWith(players: list);
  }

  static ApplyResult _bet(GameState s, int i, String kind,
      {required bool raise}) {
    final p = s.players[i];
    final legal = legalActions(s, p.id);
    var stake = s.stake;
    int amount;
    if (raise) {
      if (!legal.canRaise) {
        throw const InvalidActionException('Cannot raise');
      }
      stake = legal.newStake;
      amount = legal.raiseAmount;
    } else {
      if (!legal.canCall) {
        throw const InvalidActionException('Not enough chips to call');
      }
      amount = legal.callAmount;
    }

    var next = _setPlayer(s, i,
        p.copyWith(chips: p.chips - amount, invested: p.invested + amount));
    next = next.copyWith(pot: s.pot + amount, stake: stake);
    final events = [
      GameEvent(GameEvent.playerBet, {
        'playerId': p.id,
        'kind': kind,
        'amount': amount,
        'blind': !p.seen,
        'pot': next.pot,
      }),
    ];

    if (next.pot >= next.settings.potLimit) {
      // Pot limit reached: forced showdown, strongest hand(s) win.
      return _finish(next, events, const [], showdown: true);
    }
    return _advance(next, i, events);
  }

  static ApplyResult _fold(GameState s, int i) {
    final p = s.players[i];
    var next = _setPlayer(s, i, p.copyWith(folded: true));
    final events = [GameEvent(GameEvent.playerFolded, {'playerId': p.id})];
    final active = next.activePlayers;
    if (active.length == 1) {
      return _finish(next, events, [active.first.id], showdown: false);
    }
    return _advance(next, i, events);
  }

  static ApplyResult _show(GameState s, int i) {
    final legal = legalActions(s, s.players[i].id);
    if (!legal.canShow) {
      throw const InvalidActionException('Show needs exactly two players');
    }
    final p = s.players[i];
    final amount = legal.showAmount;
    final next = _setPlayer(s, i,
            p.copyWith(chips: p.chips - amount, invested: p.invested + amount))
        .copyWith(pot: s.pot + amount);
    final events = [
      GameEvent(GameEvent.playerBet, {
        'playerId': p.id,
        'kind': 'SHOW',
        'amount': amount,
        'blind': !p.seen,
        'pot': next.pot,
      }),
    ];
    final other = next.activePlayers.firstWhere((e) => e.id != p.id);
    final cmp = HandEvaluator.compare(p.hand, other.hand);
    // On an exact tie the player who asked for the show loses.
    final winner = cmp > 0 ? p.id : other.id;
    return _finish(next, events, [winner], showdown: true);
  }

  static ApplyResult _requestSideShow(GameState s, int i) {
    final legal = legalActions(s, s.players[i].id);
    if (!legal.canSideShow) {
      throw const InvalidActionException('Side show not allowed');
    }
    final p = s.players[i];
    final target = s.players[_previousActive(s, i)];
    final amount = legal.callAmount;
    var next = _setPlayer(s, i,
        p.copyWith(chips: p.chips - amount, invested: p.invested + amount));
    next = next.copyWith(
      pot: s.pot + amount,
      pendingSideShow: PendingSideShow(p.id, target.id),
    );
    return ApplyResult(next, [
      GameEvent(GameEvent.playerBet, {
        'playerId': p.id,
        'kind': 'SIDE_SHOW',
        'amount': amount,
        'blind': false,
        'pot': next.pot,
      }),
      GameEvent(GameEvent.sideShowRequested,
          {'playerId': p.id, 'targetId': target.id}),
    ]);
  }

  static ApplyResult _resolveSideShow(
      GameState s, PendingSideShow pending, bool accept) {
    final ri = s.indexOf(pending.requesterId);
    var next = s.copyWith(pendingSideShow: null);
    final events = <GameEvent>[];

    if (!accept) {
      events.add(GameEvent(GameEvent.sideShowResolved, {
        'playerId': pending.requesterId,
        'targetId': pending.responderId,
        'accepted': false,
      }));
      return _advance(next, ri, events);
    }

    final requester = s.playerById(pending.requesterId);
    final responder = s.playerById(pending.responderId);
    final cmp = HandEvaluator.compare(requester.hand, responder.hand);
    // Tie: the requester loses.
    final loser = cmp > 0 ? responder : requester;
    next = _setPlayer(next, next.indexOf(loser.id), loser.copyWith(folded: true));
    events
      ..add(GameEvent(GameEvent.sideShowResolved, {
        'playerId': pending.requesterId,
        'targetId': pending.responderId,
        'accepted': true,
        'loserId': loser.id,
      }))
      ..add(GameEvent(GameEvent.playerFolded, {'playerId': loser.id}));
    return _advance(next, ri, events);
  }

  static ApplyResult _advance(GameState s, int from, List<GameEvent> events) {
    final nextIndex = _nextActive(s, from);
    final next = s.copyWith(
        currentIndex: nextIndex, turnNumber: s.turnNumber + 1);
    return ApplyResult(next, [
      ...events,
      GameEvent(GameEvent.turnChanged, {'playerId': next.players[nextIndex].id}),
    ]);
  }

  static ApplyResult _finish(
    GameState s,
    List<GameEvent> events,
    List<String> winners, {
    required bool showdown,
  }) {
    var winnerIds = winners;
    if (showdown && winners.isEmpty) {
      winnerIds = _strongest(s);
    }
    final share = s.pot ~/ winnerIds.length;
    final remainder = s.pot - share * winnerIds.length;
    final payouts = <String, int>{
      for (var k = 0; k < winnerIds.length; k++)
        winnerIds[k]: share + (k == 0 ? remainder : 0),
    };
    final players = [
      for (final p in s.players)
        payouts.containsKey(p.id)
            ? p.copyWith(chips: p.chips + payouts[p.id]!)
            : p,
    ];
    final handName = showdown
        ? HandEvaluator.evaluate(s.playerById(winnerIds.first).hand).name
        : null;
    final next = s.copyWith(
      players: players,
      status: GameStatus.finished,
      winnerIds: winnerIds,
      payouts: payouts,
      winningHandName: handName,
      showdown: showdown,
    );
    return ApplyResult(next, [
      ...events,
      GameEvent(GameEvent.gameEnded, {
        'winnerIds': winnerIds,
        'payouts': payouts,
        'pot': s.pot,
        'showdown': showdown,
        'handName': handName,
      }),
    ]);
  }

  static List<String> _strongest(GameState s) {
    final active = s.activePlayers;
    final best = active
        .map((p) => HandEvaluator.evaluate(p.hand).score)
        .reduce((a, b) => a > b ? a : b);
    return [
      for (final p in active)
        if (HandEvaluator.evaluate(p.hand).score == best) p.id
    ];
  }
}
