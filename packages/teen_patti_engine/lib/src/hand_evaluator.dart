import 'card.dart';

/// Ordered weakest to strongest.
enum HandCategory {
  highCard('High Card'),
  pair('Pair'),
  color('Color'),
  sequence('Sequence'),
  pureSequence('Pure Sequence'),
  trail('Trail');

  const HandCategory(this.label);
  final String label;
}

class HandRank implements Comparable<HandRank> {
  const HandRank(this.category, this.score);
  final HandCategory category;

  /// Totally ordered score: higher always wins, equal means a tie.
  final int score;

  String get name => category.label;

  @override
  int compareTo(HandRank other) => score.compareTo(other.score);

  @override
  String toString() => '$name($score)';
}

/// Deterministic Teen Patti hand evaluation.
///
/// Ranking: Trail > Pure Sequence > Sequence > Color > Pair > High Card.
/// Sequences: A-K-Q is highest, then A-2-3, then K-Q-J ... 4-3-2.
abstract final class HandEvaluator {
  static const _categoryWeight = 1000000;

  static HandRank evaluate(List<PlayingCard> cards) {
    if (cards.length != 3) {
      throw ArgumentError('A Teen Patti hand has exactly 3 cards');
    }
    final v = cards.map((c) => c.rank.value).toList()
      ..sort((a, b) => b.compareTo(a));
    final sameSuit = cards.every((c) => c.suit == cards.first.suit);

    int make(HandCategory c, int tie) =>
        c.index * _categoryWeight + tie;

    if (v[0] == v[2]) {
      return HandRank(HandCategory.trail, make(HandCategory.trail, v[0]));
    }

    final isA23 = v[0] == 14 && v[1] == 3 && v[2] == 2;
    final isRun = v[0] - v[1] == 1 && v[1] - v[2] == 1;
    if (isRun || isA23) {
      // A-K-Q = 28, A-2-3 = 27, K-Q-J = 26 ... 4-3-2 = 8.
      final seqScore = isA23 ? 27 : v[0] * 2;
      final cat =
          sameSuit ? HandCategory.pureSequence : HandCategory.sequence;
      return HandRank(cat, make(cat, seqScore));
    }

    if (sameSuit) {
      return HandRank(
          HandCategory.color, make(HandCategory.color, _kickers(v)));
    }

    if (v[0] == v[1] || v[1] == v[2]) {
      final pair = v[1];
      final kicker = v[0] == v[1] ? v[2] : v[0];
      return HandRank(
          HandCategory.pair, make(HandCategory.pair, pair * 15 + kicker));
    }

    return HandRank(
        HandCategory.highCard, make(HandCategory.highCard, _kickers(v)));
  }

  static int _kickers(List<int> v) => v[0] * 225 + v[1] * 15 + v[2];

  /// Positive if [a] beats [b], negative if [b] wins, 0 for an exact tie.
  static int compare(List<PlayingCard> a, List<PlayingCard> b) =>
      evaluate(a).compareTo(evaluate(b));

  /// Returns the stronger hand, or `null` on a tie.
  static List<PlayingCard>? stronger(List<PlayingCard> a, List<PlayingCard> b) {
    final c = compare(a, b);
    if (c == 0) return null;
    return c > 0 ? a : b;
  }
}
