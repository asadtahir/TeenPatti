import 'card.dart';
import 'settings.dart';

class PlayerState {
  const PlayerState({
    required this.id,
    required this.name,
    required this.chips,
    this.isBot = false,
    this.hand = const [],
    this.seen = false,
    this.folded = false,
    this.invested = 0,
  });

  final String id;
  final String name;
  final int chips;
  final bool isBot;

  /// Empty when hidden from the viewer (see [GameState.redactedFor]).
  final List<PlayingCard> hand;
  final bool seen;
  final bool folded;

  /// Chips put into the pot this game.
  final int invested;

  PlayerState copyWith({
    int? chips,
    List<PlayingCard>? hand,
    bool? seen,
    bool? folded,
    int? invested,
  }) =>
      PlayerState(
        id: id,
        name: name,
        chips: chips ?? this.chips,
        isBot: isBot,
        hand: hand ?? this.hand,
        seen: seen ?? this.seen,
        folded: folded ?? this.folded,
        invested: invested ?? this.invested,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'chips': chips,
        'isBot': isBot,
        'hand': [for (final c in hand) c.toJson()],
        'seen': seen,
        'folded': folded,
        'invested': invested,
      };

  factory PlayerState.fromJson(Map<String, Object?> j) => PlayerState(
        id: j['id'] as String,
        name: j['name'] as String,
        chips: j['chips'] as int,
        isBot: j['isBot'] as bool? ?? false,
        hand: [for (final c in (j['hand'] as List)) PlayingCard.fromJson(c as int)],
        seen: j['seen'] as bool,
        folded: j['folded'] as bool,
        invested: j['invested'] as int,
      );
}

enum GameStatus { waiting, inProgress, finished }

class PendingSideShow {
  const PendingSideShow(this.requesterId, this.responderId);
  final String requesterId;
  final String responderId;
}

class GameState {
  const GameState({
    required this.players,
    required this.settings,
    this.dealerIndex = 0,
    this.currentIndex = 0,
    this.pot = 0,
    this.stake = 0,
    this.turnNumber = 0,
    this.status = GameStatus.waiting,
    this.pendingSideShow,
    this.winnerIds = const [],
    this.payouts = const {},
    this.winningHandName,
    this.showdown = false,
  });

  final List<PlayerState> players;
  final GameSettings settings;
  final int dealerIndex;
  final int currentIndex;
  final int pot;

  /// Current blind stake. Seen players pay double this.
  final int stake;
  final int turnNumber;
  final GameStatus status;
  final PendingSideShow? pendingSideShow;
  final List<String> winnerIds;
  final Map<String, int> payouts;
  final String? winningHandName;

  /// True when the game ended with hands revealed (show / pot limit).
  final bool showdown;

  PlayerState get currentPlayer => players[currentIndex];
  bool get isFinished => status == GameStatus.finished;

  PlayerState playerById(String id) => players.firstWhere(
        (p) => p.id == id,
        orElse: () => throw ArgumentError('Unknown player $id'),
      );

  int indexOf(String id) => players.indexWhere((p) => p.id == id);

  List<PlayerState> get activePlayers =>
      [for (final p in players) if (!p.folded) p];

  GameState copyWith({
    List<PlayerState>? players,
    int? currentIndex,
    int? pot,
    int? stake,
    int? turnNumber,
    GameStatus? status,
    Object? pendingSideShow = _unset,
    List<String>? winnerIds,
    Map<String, int>? payouts,
    String? winningHandName,
    bool? showdown,
  }) =>
      GameState(
        players: players ?? this.players,
        settings: settings,
        dealerIndex: dealerIndex,
        currentIndex: currentIndex ?? this.currentIndex,
        pot: pot ?? this.pot,
        stake: stake ?? this.stake,
        turnNumber: turnNumber ?? this.turnNumber,
        status: status ?? this.status,
        pendingSideShow: identical(pendingSideShow, _unset)
            ? this.pendingSideShow
            : pendingSideShow as PendingSideShow?,
        winnerIds: winnerIds ?? this.winnerIds,
        payouts: payouts ?? this.payouts,
        winningHandName: winningHandName ?? this.winningHandName,
        showdown: showdown ?? this.showdown,
      );

  /// Server-side view for one player: hides every hand the viewer must not see.
  /// A player sees their own hand only after looking at it; everyone's
  /// non-folded hands are revealed after a showdown.
  GameState redactedFor(String? viewerId) {
    final reveal = isFinished && showdown;
    return GameState(
      players: [
        for (final p in players)
          if ((p.id == viewerId && p.seen) || (reveal && !p.folded))
            p
          else
            p.copyWith(hand: const []),
      ],
      settings: settings,
      dealerIndex: dealerIndex,
      currentIndex: currentIndex,
      pot: pot,
      stake: stake,
      turnNumber: turnNumber,
      status: status,
      pendingSideShow: pendingSideShow,
      winnerIds: winnerIds,
      payouts: payouts,
      winningHandName: winningHandName,
      showdown: showdown,
    );
  }

  Map<String, Object?> toJson() => {
        'players': [for (final p in players) p.toJson()],
        'settings': settings.toJson(),
        'dealerIndex': dealerIndex,
        'currentIndex': currentIndex,
        'pot': pot,
        'stake': stake,
        'turnNumber': turnNumber,
        'status': status.name,
        'pending': pendingSideShow == null
            ? null
            : [pendingSideShow!.requesterId, pendingSideShow!.responderId],
        'winnerIds': winnerIds,
        'payouts': payouts,
        'winningHandName': winningHandName,
        'showdown': showdown,
      };

  factory GameState.fromJson(Map<String, Object?> j) {
    final pending = j['pending'] as List?;
    return GameState(
      players: [
        for (final p in (j['players'] as List))
          PlayerState.fromJson((p as Map).cast<String, Object?>())
      ],
      settings: GameSettings.fromJson(
          (j['settings'] as Map).cast<String, Object?>()),
      dealerIndex: j['dealerIndex'] as int,
      currentIndex: j['currentIndex'] as int,
      pot: j['pot'] as int,
      stake: j['stake'] as int,
      turnNumber: j['turnNumber'] as int,
      status: GameStatus.values.byName(j['status'] as String),
      pendingSideShow: pending == null
          ? null
          : PendingSideShow(pending[0] as String, pending[1] as String),
      winnerIds: [for (final w in (j['winnerIds'] as List)) w as String],
      payouts: {
        for (final e in (j['payouts'] as Map).entries)
          e.key as String: e.value as int
      },
      winningHandName: j['winningHandName'] as String?,
      showdown: j['showdown'] as bool,
    );
  }
}

const Object _unset = Object();
