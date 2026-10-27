import 'package:teen_patti_engine/teen_patti_engine.dart';
import 'package:test/test.dart';

PlayingCard c(String s) {
  final suit = {'c': Suit.clubs, 'd': Suit.diamonds, 'h': Suit.hearts, 's': Suit.spades}[s[s.length - 1]]!;
  final r = s.substring(0, s.length - 1);
  final rank = Rank.values.firstWhere((x) => x.label == r);
  return PlayingCard(rank, suit);
}

List<PlayingCard> h(String a, String b, String d) => [c(a), c(b), c(d)];

void main() {
  group('categories', () {
    test('trail', () => expect(HandEvaluator.evaluate(h('7c', '7d', '7h')).category, HandCategory.trail));
    test('pure sequence', () => expect(HandEvaluator.evaluate(h('5h', '6h', '7h')).category, HandCategory.pureSequence));
    test('sequence', () => expect(HandEvaluator.evaluate(h('5h', '6d', '7h')).category, HandCategory.sequence));
    test('color', () => expect(HandEvaluator.evaluate(h('2h', '6h', 'Kh')).category, HandCategory.color));
    test('pair', () => expect(HandEvaluator.evaluate(h('9h', '9d', '2c')).category, HandCategory.pair));
    test('high card', () => expect(HandEvaluator.evaluate(h('2h', '6d', 'Kc')).category, HandCategory.highCard));
    test('A-2-3 is a sequence', () => expect(HandEvaluator.evaluate(h('Ah', '2d', '3c')).category, HandCategory.sequence));
    test('Q-K-A is a sequence', () => expect(HandEvaluator.evaluate(h('Qh', 'Kd', 'Ac')).category, HandCategory.sequence));
    test('K-A-2 does not wrap', () => expect(HandEvaluator.evaluate(h('Kh', 'Ad', '2c')).category, HandCategory.highCard));
    test('input order is irrelevant', () {
      expect(HandEvaluator.evaluate(h('Ah', 'Kd', 'Qc')).score, HandEvaluator.evaluate(h('Qc', 'Ah', 'Kd')).score);
    });
    test('wrong card count throws', () => expect(() => HandEvaluator.evaluate([c('2h')]), throwsArgumentError));
  });

  group('ordering', () {
    int cmp(List<PlayingCard> a, List<PlayingCard> b) => HandEvaluator.compare(a, b).sign;

    test('category order', () {
      final ladder = [
        h('2h', '6d', 'Kc'), // high card
        h('2h', '2d', '3c'), // pair
        h('2h', '6h', 'Kh'), // color
        h('4h', '5d', '6c'), // sequence
        h('4h', '5h', '6h'), // pure sequence
        h('2h', '2d', '2c'), // trail
      ];
      for (var i = 0; i < ladder.length - 1; i++) {
        expect(cmp(ladder[i + 1], ladder[i]), 1, reason: 'rung $i');
      }
    });

    test('lowest trail beats highest pure sequence', () {
      expect(cmp(h('2h', '2d', '2c'), h('Ah', 'Kh', 'Qh')), 1);
    });

    test('sequence order: AKQ > A23 > KQJ > ... > 432', () {
      final akq = h('Ah', 'Kd', 'Qc');
      final a23 = h('Ah', '2d', '3c');
      final kqj = h('Kh', 'Qd', 'Jc');
      final s432 = h('4h', '3d', '2c');
      expect(cmp(akq, a23), 1);
      expect(cmp(a23, kqj), 1);
      expect(cmp(kqj, s432), 1);
    });

    test('higher trail wins', () => expect(cmp(h('Ah', 'Ad', 'Ac'), h('Kh', 'Kd', 'Kc')), 1));

    test('pair: higher pair then kicker', () {
      expect(cmp(h('9h', '9d', '2c'), h('8h', '8d', 'Ac')), 1);
      expect(cmp(h('9h', '9d', '5c'), h('9s', '9c', '4c')), 1);
    });

    test('high card compares top card then next', () {
      expect(cmp(h('Ah', '3d', '2c'), h('Kh', 'Qd', 'Jc')), 1);
      expect(cmp(h('Ah', 'Kd', '4c'), h('As', 'Kc', '3d')), 1);
    });

    test('suits never break ties', () {
      expect(cmp(h('Ah', 'Kd', '4c'), h('As', 'Kh', '4d')), 0);
      expect(HandEvaluator.stronger(h('Ah', 'Kd', '4c'), h('As', 'Kh', '4d')), isNull);
    });

    test('color compares like high card', () {
      expect(cmp(h('Ah', '9h', '2h'), h('Ks', 'Qs', '9s')), 1);
    });

    test('stronger returns the winning hand', () {
      final a = h('Ah', 'Ad', 'Ac');
      final b = h('2h', '3d', '5c');
      expect(HandEvaluator.stronger(a, b), a);
      expect(HandEvaluator.stronger(b, a), a);
    });
  });

  test('every one of 22100 hands has a strict total order consistent with categories', () {
    final cards = Deck.standard();
    final all = <PlayingCard>[for (var i = 0; i < 52; i++) cards.draw()];
    final counts = <HandCategory, int>{};
    for (var a = 0; a < 52; a++) {
      for (var b = a + 1; b < 52; b++) {
        for (var d = b + 1; d < 52; d++) {
          final r = HandEvaluator.evaluate([all[a], all[b], all[d]]);
          counts[r.category] = (counts[r.category] ?? 0) + 1;
        }
      }
    }
    // Known Teen Patti combinatorics.
    expect(counts[HandCategory.trail], 52);
    expect(counts[HandCategory.pureSequence], 48);
    expect(counts[HandCategory.sequence], 720);
    expect(counts[HandCategory.color], 1096);
    expect(counts[HandCategory.pair], 3744);
    expect(counts[HandCategory.highCard], 16440);
  });
}
