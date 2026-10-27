import 'card.dart';
import 'random_source.dart';

class Deck {
  Deck._(this._cards);

  /// Ordered 52-card deck.
  factory Deck.standard() => Deck._([
        for (final r in Rank.values)
          for (final s in Suit.values) PlayingCard(r, s),
      ]);

  /// Fisher-Yates shuffle driven by [random].
  factory Deck.shuffled(RandomSource random) {
    final cards = Deck.standard()._cards;
    for (var i = cards.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final tmp = cards[i];
      cards[i] = cards[j];
      cards[j] = tmp;
    }
    return Deck._(cards);
  }

  final List<PlayingCard> _cards;

  int get remaining => _cards.length;

  PlayingCard draw() {
    if (_cards.isEmpty) throw StateError('Deck is empty');
    return _cards.removeLast();
  }
}
