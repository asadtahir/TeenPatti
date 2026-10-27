/// Everything a player can ask the engine to do. Validated by the engine.
sealed class GameAction {
  const GameAction(this.playerId);
  final String playerId;

  String get type;

  Map<String, Object?> toJson() => {'type': type, 'playerId': playerId};

  factory GameAction.fromJson(Map<String, Object?> j) {
    final id = j['playerId'] as String;
    switch (j['type']) {
      case 'SEE':
        return SeeCards(id);
      case 'CALL':
        return Call(id);
      case 'RAISE':
        return Raise(id);
      case 'FOLD':
        return Fold(id);
      case 'SHOW':
        return Show(id);
      case 'SIDE_SHOW':
        return SideShowRequest(id);
      case 'SIDE_SHOW_REPLY':
        return SideShowResponse(id, accept: j['accept'] == true);
      default:
        throw FormatException('Unknown action type ${j['type']}');
    }
  }
}

/// Look at your cards (a blind player becomes "seen").
class SeeCards extends GameAction {
  const SeeCards(super.playerId);
  @override
  String get type => 'SEE';
}

/// Match the current stake (chaal). Blind pays 1x, seen pays 2x.
class Call extends GameAction {
  const Call(super.playerId);
  @override
  String get type => 'CALL';
}

/// Double the stake (capped) and pay it.
class Raise extends GameAction {
  const Raise(super.playerId);
  @override
  String get type => 'RAISE';
}

class Fold extends GameAction {
  const Fold(super.playerId);
  @override
  String get type => 'FOLD';
}

/// Only legal when exactly two players remain.
class Show extends GameAction {
  const Show(super.playerId);
  @override
  String get type => 'SHOW';
}

/// Ask the previous active (seen) player to compare cards privately.
class SideShowRequest extends GameAction {
  const SideShowRequest(super.playerId);
  @override
  String get type => 'SIDE_SHOW';
}

class SideShowResponse extends GameAction {
  const SideShowResponse(super.playerId, {required this.accept});
  final bool accept;
  @override
  String get type => 'SIDE_SHOW_REPLY';

  @override
  Map<String, Object?> toJson() => {...super.toJson(), 'accept': accept};
}
