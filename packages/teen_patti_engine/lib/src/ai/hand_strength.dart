import '../card.dart';
import '../hand_evaluator.dart';

/// Exact hand strength: the fraction of all 22,100 possible hands that
/// the given hand strictly beats (0 = worst, 1 = best), computed once.
abstract final class HandStrengthAnalyzer {
  static List<int>? _sortedScores;

  static List<int> _scores() {
    final cached = _sortedScores;
    if (cached != null) return cached;
    final cards = [
      for (final r in Rank.values)
        for (final s in Suit.values) PlayingCard(r, s),
    ];
    final scores = <int>[];
    for (var a = 0; a < 52; a++) {
      for (var b = a + 1; b < 52; b++) {
        for (var c = b + 1; c < 52; c++) {
          scores.add(
              HandEvaluator.evaluate([cards[a], cards[b], cards[c]]).score);
        }
      }
    }
    scores.sort();
    return _sortedScores = scores;
  }

  static double strength(List<PlayingCard> hand) {
    final scores = _scores();
    final target = HandEvaluator.evaluate(hand).score;
    // Count of hands with score < target (lower bound).
    var lo = 0, hi = scores.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (scores[mid] < target) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo / scores.length;
  }
}
