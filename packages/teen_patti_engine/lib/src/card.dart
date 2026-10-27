enum Suit {
  clubs('♣'),
  diamonds('♦'),
  hearts('♥'),
  spades('♠');

  const Suit(this.symbol);
  final String symbol;
  bool get isRed => this == diamonds || this == hearts;
}

/// Ranks ordered low to high. Ace is high; A-2-3 is handled by the evaluator.
enum Rank {
  two('2'),
  three('3'),
  four('4'),
  five('5'),
  six('6'),
  seven('7'),
  eight('8'),
  nine('9'),
  ten('10'),
  jack('J'),
  queen('Q'),
  king('K'),
  ace('A');

  const Rank(this.label);
  final String label;

  /// Numeric value 2..14.
  int get value => index + 2;
}

class PlayingCard {
  const PlayingCard(this.rank, this.suit);
  final Rank rank;
  final Suit suit;

  /// Compact wire format: 0..51.
  int toJson() => rank.index * 4 + suit.index;

  factory PlayingCard.fromJson(int code) {
    if (code < 0 || code > 51) {
      throw ArgumentError.value(code, 'code', 'card code must be 0..51');
    }
    return PlayingCard(Rank.values[code ~/ 4], Suit.values[code % 4]);
  }

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => Object.hash(rank, suit);

  @override
  String toString() => '${rank.label}${suit.symbol}';
}
