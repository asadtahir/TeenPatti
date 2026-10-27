import 'package:teen_patti_engine/teen_patti_engine.dart';
import 'package:test/test.dart';

const settings = GameSettings(bootAmount: 100, maxStakeMultiple: 8, potLimitMultiple: 1000);

List<PlayerState> seats(int n, {int chips = 10000}) => [
      for (var i = 0; i < n; i++) PlayerState(id: 'p$i', name: 'P$i', chips: chips),
    ];

GameState start(int n, {int seed = 1, int chips = 10000, GameSettings s = settings}) =>
    TeenPattiEngine.startGame(
      players: seats(n, chips: chips),
      settings: s,
      random: SeededRandomSource(seed),
    ).state;

GameState act(GameState s, GameAction a) => TeenPattiEngine.apply(s, a).state;

/// Force known hands without touching the dealing logic.
GameState withHands(GameState s, Map<String, List<PlayingCard>> hands) => s.copyWith(
      players: [for (final p in s.players) hands.containsKey(p.id) ? p.copyWith(hand: hands[p.id]) : p],
    );

const trail = [PlayingCard(Rank.ace, Suit.clubs), PlayingCard(Rank.ace, Suit.hearts), PlayingCard(Rank.ace, Suit.spades)];
const weak = [PlayingCard(Rank.two, Suit.clubs), PlayingCard(Rank.five, Suit.hearts), PlayingCard(Rank.nine, Suit.spades)];

void main() {
  group('deck & dealing', () {
    test('standard deck has 52 unique cards', () {
      final d = Deck.standard();
      final seen = <PlayingCard>{};
      while (d.remaining > 0) {
        seen.add(d.draw());
      }
      expect(seen.length, 52);
    });

    test('shuffle is deterministic per seed and differs across seeds', () {
      List<PlayingCard> order(int seed) {
        final d = Deck.shuffled(SeededRandomSource(seed));
        return [for (var i = 0; i < 52; i++) d.draw()];
      }

      expect(order(7), order(7));
      expect(order(7), isNot(order(8)));
      expect(order(7).toSet().length, 52);
    });

    test('3 unique cards per player, boot collected', () {
      final s = start(5);
      final all = [for (final p in s.players) ...p.hand];
      expect(all.length, 15);
      expect(all.toSet().length, 15);
      expect(s.pot, 500);
      expect(s.players.every((p) => p.chips == 9900 && p.invested == 100), isTrue);
      expect(s.currentIndex, 1); // left of dealer
    });

    test('rejects bad tables', () {
      expect(() => start(1), throwsA(isA<InvalidActionException>()));
      expect(() => start(7), throwsA(isA<InvalidActionException>()));
      expect(
        () => TeenPattiEngine.startGame(
            players: seats(3, chips: 50), settings: settings, random: SeededRandomSource(1)),
        throwsA(isA<InvalidActionException>()),
      );
    });
  });

  group('betting', () {
    test('blind call pays stake, seen call pays double', () {
      var s = start(3);
      s = act(s, const Call('p1')); // blind
      expect(s.pot, 400);
      expect(s.players[1].chips, 9800);
      expect(s.currentPlayer.id, 'p2');
      s = act(s, const SeeCards('p2'));
      s = act(s, const Call('p2')); // seen pays 2x
      expect(s.pot, 600);
      expect(s.players[2].chips, 9700);
    });

    test('raise doubles stake, capped at max', () {
      var s = start(3);
      s = act(s, const Raise('p1'));
      expect(s.stake, 200);
      expect(s.pot, 300 + 200);
      s = act(s, const Raise('p2'));
      s = act(s, const Raise('p0'));
      expect(s.stake, 800); // max = 8 * 100
      s = act(s, const Call('p1'));
      expect(TeenPattiEngine.legalActions(s, 'p2').canRaise, isFalse);
      expect(() => act(s, const Raise('p2')), throwsA(isA<InvalidActionException>()));
    });

    test('seeing cards does not consume a turn', () {
      var s = start(3);
      s = act(s, const SeeCards('p0'));
      expect(s.currentPlayer.id, 'p1');
      expect(s.playerById('p0').seen, isTrue);
      expect(() => act(s, const SeeCards('p0')), throwsA(isA<InvalidActionException>()));
    });

    test('out of turn and unknown players are rejected', () {
      final s = start(3);
      expect(() => act(s, const Call('p2')), throwsA(isA<InvalidActionException>()));
      expect(() => act(s, const Call('nobody')), throwsA(isA<InvalidActionException>()));
    });

    test('insufficient chips cannot call', () {
      var s = start(3, chips: 250);
      expect(TeenPattiEngine.legalActions(s, 'p1').canCall, isTrue);
      s = act(s, const SeeCards('p1'));
      // seen pays 200 but only has 150
      final legal = TeenPattiEngine.legalActions(s, 'p1');
      expect(legal.canCall, isFalse);
      expect(legal.canFold, isTrue);
      expect(() => act(s, const Call('p1')), throwsA(isA<InvalidActionException>()));
    });
  });

  group('endings', () {
    test('last player standing wins pot without showdown', () {
      var s = start(3);
      s = act(s, const Call('p1'));
      s = act(s, const Fold('p2'));
      s = act(s, const Fold('p0'));
      expect(s.isFinished, isTrue);
      expect(s.winnerIds, ['p1']);
      expect(s.showdown, isFalse);
      expect(s.payouts['p1'], 400);
      expect(s.playerById('p1').chips, 9900 - 100 + 400);
    });

    test('actions after game end are rejected', () {
      var s = start(2);
      s = act(s, const Fold('p1'));
      expect(() => act(s, const Call('p0')), throwsA(isA<InvalidActionException>()));
    });

    test('show: stronger hand wins, requester pays', () {
      var s = start(2);
      s = withHands(s, {'p1': trail, 'p0': weak});
      s = act(s, const Show('p1'));
      expect(s.winnerIds, ['p1']);
      expect(s.showdown, isTrue);
      expect(s.winningHandName, 'Trail');
      expect(s.pot, 300);
    });

    test('show: weaker requester loses', () {
      var s = start(2);
      s = withHands(s, {'p1': weak, 'p0': trail});
      s = act(s, const Show('p1'));
      expect(s.winnerIds, ['p0']);
    });

    test('show tie: requester loses', () {
      var s = start(2);
      s = withHands(s, {
        'p1': const [PlayingCard(Rank.ace, Suit.clubs), PlayingCard(Rank.king, Suit.hearts), PlayingCard(Rank.four, Suit.spades)],
        'p0': const [PlayingCard(Rank.ace, Suit.hearts), PlayingCard(Rank.king, Suit.clubs), PlayingCard(Rank.four, Suit.diamonds)],
      });
      s = act(s, const Show('p1'));
      expect(s.winnerIds, ['p0']);
    });

    test('show needs exactly two players', () {
      final s = start(3);
      expect(() => act(s, const Show('p1')), throwsA(isA<InvalidActionException>()));
    });

    test('pot limit forces showdown; ties split the pot', () {
      const tiny = GameSettings(bootAmount: 100, maxStakeMultiple: 8, potLimitMultiple: 4);
      var s = start(3, s: tiny); // pot 300, limit 400
      s = withHands(s, {
        'p0': const [PlayingCard(Rank.ace, Suit.clubs), PlayingCard(Rank.king, Suit.hearts), PlayingCard(Rank.four, Suit.spades)],
        'p1': const [PlayingCard(Rank.ace, Suit.hearts), PlayingCard(Rank.king, Suit.clubs), PlayingCard(Rank.four, Suit.diamonds)],
        'p2': weak,
      });
      s = act(s, const Call('p1')); // pot 400 -> forced showdown
      expect(s.isFinished, isTrue);
      expect(s.showdown, isTrue);
      expect(s.winnerIds.toSet(), {'p0', 'p1'});
      expect(s.payouts.values.fold<int>(0, (a, b) => a + b), 400);
    });

    test('chips are conserved across a game', () {
      var s = start(4);
      final before = s.players.fold<int>(0, (a, p) => a + p.chips) + s.pot;
      s = act(s, const Raise('p1'));
      s = act(s, const Fold('p2'));
      s = act(s, const Call('p3'));
      s = act(s, const Fold('p0'));
      s = act(s, const Fold('p1'));
      expect(s.isFinished, isTrue);
      expect(s.players.fold<int>(0, (a, p) => a + p.chips), before);
    });
  });

  group('side show', () {
    GameState seenAll(GameState s) {
      for (final p in s.players) {
        s = act(s, SeeCards(p.id));
      }
      return s;
    }

    test('requires seen requester and seen target', () {
      var s = start(3);
      expect(TeenPattiEngine.legalActions(s, 'p1').canSideShow, isFalse);
      s = act(s, const SeeCards('p1'));
      expect(TeenPattiEngine.legalActions(s, 'p1').canSideShow, isFalse); // p0 blind
      s = act(s, const SeeCards('p0'));
      expect(TeenPattiEngine.legalActions(s, 'p1').canSideShow, isTrue);
    });

    test('accepted: weaker hand folds, turn moves on', () {
      var s = seenAll(start(3));
      s = withHands(s, {'p1': trail, 'p0': weak});
      s = act(s, const SideShowRequest('p1'));
      expect(s.pendingSideShow?.responderId, 'p0');
      expect(() => act(s, const Call('p2')), throwsA(isA<InvalidActionException>()));
      s = act(s, const SideShowResponse('p0', accept: true));
      expect(s.playerById('p0').folded, isTrue);
      expect(s.pendingSideShow, isNull);
      expect(s.currentPlayer.id, 'p2');
    });

    test('tie: requester folds', () {
      var s = seenAll(start(3));
      s = withHands(s, {
        'p1': const [PlayingCard(Rank.ace, Suit.clubs), PlayingCard(Rank.king, Suit.hearts), PlayingCard(Rank.four, Suit.spades)],
        'p0': const [PlayingCard(Rank.ace, Suit.hearts), PlayingCard(Rank.king, Suit.clubs), PlayingCard(Rank.four, Suit.diamonds)],
      });
      s = act(s, const SideShowRequest('p1'));
      s = act(s, const SideShowResponse('p0', accept: true));
      expect(s.playerById('p1').folded, isTrue);
    });

    test('declined: nobody folds, turn moves on', () {
      var s = seenAll(start(3));
      s = act(s, const SideShowRequest('p1'));
      s = act(s, const SideShowResponse('p0', accept: false));
      expect(s.players.any((p) => p.folded), isFalse);
      expect(s.currentPlayer.id, 'p2');
    });

    test('only the target can respond', () {
      var s = seenAll(start(3));
      s = act(s, const SideShowRequest('p1'));
      expect(() => act(s, const SideShowResponse('p2', accept: true)), throwsA(isA<InvalidActionException>()));
    });
  });

  group('turn management', () {
    test('folded players are skipped', () {
      var s = start(4);
      s = act(s, const Fold('p1'));
      s = act(s, const Call('p2'));
      s = act(s, const Call('p3'));
      expect(s.currentPlayer.id, 'p0');
      s = act(s, const Call('p0'));
      expect(s.currentPlayer.id, 'p2'); // p1 skipped
    });
  });

  group('serialization & redaction', () {
    test('state round-trips through JSON', () {
      final s = act(start(4), const Raise('p1'));
      final copy = GameState.fromJson(s.toJson());
      expect(copy.toJson(), s.toJson());
    });

    test('hands are hidden until seen; showdown reveals non-folded', () {
      var s = start(3);
      expect(s.redactedFor('p0').playerById('p0').hand, isEmpty);
      s = act(s, const SeeCards('p0'));
      expect(s.redactedFor('p0').playerById('p0').hand.length, 3);
      expect(s.redactedFor('p0').playerById('p1').hand, isEmpty);
      expect(s.redactedFor(null).playerById('p0').hand, isEmpty);
    });

    test('showdown reveals both hands to everyone', () {
      var s = start(2);
      s = act(s, const Show('p1'));
      final view = s.redactedFor('p0');
      expect(view.playerById('p1').hand.length, 3);
    });

    test('actions round-trip', () {
      for (final a in <GameAction>[
        const SeeCards('a'), const Call('a'), const Raise('a'), const Fold('a'),
        const Show('a'), const SideShowRequest('a'), const SideShowResponse('a', accept: true),
      ]) {
        expect(GameAction.fromJson(a.toJson()).toJson(), a.toJson());
      }
      expect(() => GameAction.fromJson({'type': 'HACK', 'playerId': 'a'}), throwsFormatException);
    });
  });
}
