import 'package:teen_patti_engine/teen_patti_engine.dart';
import 'package:test/test.dart';

const settings = GameSettings(bootAmount: 100, maxStakeMultiple: 16, potLimitMultiple: 200);

PlayingCard pc(Rank r, Suit s) => PlayingCard(r, s);

/// Plays a whole game with bots only. Returns the final state.
GameState playBots(int seed, int n, Difficulty d, {List<GameEvent>? log}) {
  final rng = SeededRandomSource(seed);
  final ids = [for (var i = 0; i < n; i++) 'b$i'];
  final ai = AIEngine.forBots(ids, d, rng);
  var res = TeenPattiEngine.startGame(
    players: [for (final id in ids) PlayerState(id: id, name: id, chips: 20000, isBot: true)],
    settings: settings,
    random: rng,
  );
  var s = res.state;
  var guard = 0;
  while (!s.isFinished) {
    if (++guard > 2000) fail('game did not terminate (seed $seed)');
    final pending = s.pendingSideShow;
    GameAction action;
    String actor;
    if (pending != null) {
      actor = pending.responderId;
      action = ai.sideShowReply(s, actor);
    } else {
      actor = s.currentPlayer.id;
      action = ai.nextAction(s, actor);
    }
    // The AI must only ever return legal moves.
    final r = TeenPattiEngine.apply(s, action);
    ai.observe(r.events);
    log?.addAll(r.events);
    s = r.state;
  }
  return s;
}

void main() {
  group('hand strength', () {
    test('trail is strongest, worst high card is weakest', () {
      final best = HandStrengthAnalyzer.strength([pc(Rank.ace, Suit.clubs), pc(Rank.ace, Suit.hearts), pc(Rank.ace, Suit.spades)]);
      final worst = HandStrengthAnalyzer.strength([pc(Rank.two, Suit.clubs), pc(Rank.three, Suit.hearts), pc(Rank.five, Suit.spades)]);
      expect(best, greaterThan(0.99));
      expect(worst, 0.0);
    });

    test('monotonic with hand category', () {
      final pair = HandStrengthAnalyzer.strength([pc(Rank.nine, Suit.clubs), pc(Rank.nine, Suit.hearts), pc(Rank.two, Suit.spades)]);
      final seq = HandStrengthAnalyzer.strength([pc(Rank.four, Suit.clubs), pc(Rank.five, Suit.hearts), pc(Rank.six, Suit.spades)]);
      expect(seq, greaterThan(pair));
    });
  });

  group('AI plays full games legally', () {
    for (final d in Difficulty.values) {
      test('${d.name}: 150 games over 3..6 players always terminate legally and conserve chips', () {
        for (var seed = 0; seed < 150; seed++) {
          final n = 3 + seed % 4;
          final s = playBots(seed, n, d);
          expect(s.isFinished, isTrue);
          expect(s.winnerIds, isNotEmpty);
          final total = s.players.fold<int>(0, (a, p) => a + p.chips);
          expect(total, 20000 * n, reason: 'seed $seed');
          expect(s.players.every((p) => p.chips >= 0), isTrue);
        }
      });
    }
  });

  group('difficulty & personality', () {
    test('conservative folds weak seen hands more than aggressive', () {
      int folds(Personality p) {
        var count = 0;
        for (var seed = 0; seed < 300; seed++) {
          final rng = SeededRandomSource(seed);
          var s = TeenPattiEngine.startGame(
            players: [for (var i = 0; i < 3; i++) PlayerState(id: 'b$i', name: 'b$i', chips: 20000)],
            settings: settings,
            random: rng,
          ).state;
          s = s.copyWith(players: [
            for (final pl in s.players)
              pl.copyWith(seen: true, hand: [pc(Rank.two, Suit.clubs), pc(Rank.seven, Suit.hearts), pc(Rank.nine, Suit.spades)]),
          ]);
          // 7-high-ish hand: 0.? strength; noise-free comparison via Hard.
          final engine = DecisionEngine(AIProfile(Difficulty.medium, p), rng);
          if (engine.decide(s, s.currentPlayer.id) is Fold) count++;
        }
        return count;
      }

      expect(folds(Personality.conservative), greaterThan(folds(Personality.aggressive)));
    });

    test('bluffer sometimes continues with garbage; conservative practically never raises', () {
      int raises(Personality p) {
        var count = 0;
        for (var seed = 0; seed < 400; seed++) {
          final rng = SeededRandomSource(seed);
          var s = TeenPattiEngine.startGame(
            players: [for (var i = 0; i < 3; i++) PlayerState(id: 'b$i', name: 'b$i', chips: 20000)],
            settings: settings,
            random: rng,
          ).state;
          s = s.copyWith(players: [
            for (final pl in s.players)
              pl.copyWith(seen: true, hand: [pc(Rank.two, Suit.clubs), pc(Rank.three, Suit.hearts), pc(Rank.five, Suit.spades)]),
          ]);
          final engine = DecisionEngine(AIProfile(Difficulty.hard, p), rng);
          if (engine.decide(s, s.currentPlayer.id) is Raise) count++;
        }
        return count;
      }

      expect(raises(Personality.bluffer), greaterThan(raises(Personality.conservative)));
    });

    test('hard AI never makes an illegal decision when short-stacked', () {
      for (var seed = 0; seed < 200; seed++) {
        final rng = SeededRandomSource(seed);
        var s = TeenPattiEngine.startGame(
          players: [
            const PlayerState(id: 'a', name: 'a', chips: 150),
            const PlayerState(id: 'b', name: 'b', chips: 20000),
          ],
          settings: settings,
          random: rng,
        ).state;
        final engine = DecisionEngine(const AIProfile(Difficulty.hard, Personality.aggressive), rng);
        final actor = s.currentPlayer.id;
        final action = engine.decide(s, actor);
        TeenPattiEngine.apply(s, action); // must not throw
      }
    });
  });
}
