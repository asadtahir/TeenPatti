/// Structured event emitted by the engine. Drives animations and network sync.
class GameEvent {
  const GameEvent(this.type, [this.data = const {}]);

  final String type;
  final Map<String, Object?> data;

  static const gameStarted = 'GAME_STARTED';
  static const bootCollected = 'BOOT_COLLECTED';
  static const cardsDealt = 'CARDS_DEALT';
  static const turnChanged = 'TURN_CHANGED';
  static const playerSeen = 'PLAYER_SEEN';
  static const playerBet = 'PLAYER_BET'; // data: kind CALL|RAISE|SHOW|SIDE_SHOW, amount
  static const playerFolded = 'PLAYER_FOLDED';
  static const sideShowRequested = 'SIDE_SHOW_REQUESTED';
  static const sideShowResolved = 'SIDE_SHOW_RESOLVED';
  static const gameEnded = 'GAME_ENDED';

  String? get playerId => data['playerId'] as String?;
  int get amount => (data['amount'] as int?) ?? 0;

  Map<String, Object?> toJson() => {'type': type, ...data};

  factory GameEvent.fromJson(Map<String, Object?> j) {
    final copy = Map<String, Object?>.of(j)..remove('type');
    return GameEvent(j['type'] as String, copy);
  }

  @override
  String toString() => 'GameEvent($type, $data)';
}
