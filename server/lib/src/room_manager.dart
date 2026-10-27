import 'dart:async';
import 'dart:io';

import 'package:teen_patti_engine/teen_patti_engine.dart';

import 'connection.dart';
import 'store.dart';

class Member {
  Member(this.user);
  final UserRecord user;
  Connection? conn;

  /// Asked to leave while a hand is running; removed after settlement.
  bool leaving = false;
  Timer? dropTimer;

  bool get connected => conn != null && !conn!.closed;
}

class Room {
  Room(this.code, this.hostId, this.maxPlayers, this.boot, {required this.isPublic, this.autoStart = false});

  final String code;
  String hostId;
  final int maxPlayers;
  final int boot;
  final bool isPublic;
  final bool autoStart;

  final members = <String, Member>{};
  GameState? game;
  String gameId = '';
  Map<String, int> startChips = {};
  int dealerIndex = -1;
  int seq = 0;
  Timer? turnTimer;
  Timer? startTimer;
  DateTime? deadline;

  /// userId -> actionId -> cached ack (idempotency).
  final seenActions = <String, Map<String, Map<String, Object?>>>{};

  bool get inProgress => game != null && !game!.isFinished;
}

/// All room, game and anti-cheat logic. The server is the only source of truth:
/// it deals, validates every action, runs timers and settles balances.
class RoomManager {
  RoomManager({
    required this.store,
    RandomSource? random,
    this.turnSeconds = 15,
    this.sideShowSeconds = 10,
    this.disconnectedTurn = const Duration(seconds: 4),
    this.disconnectGrace = const Duration(seconds: 60),
    this.quickPlayStartDelay = const Duration(milliseconds: 800),
    this.nextHandDelay = const Duration(seconds: 6),
    this.maxStrikes = 10,
  }) : random = random ?? SecureRandomSource();

  final Store store;
  final RandomSource random;
  final int turnSeconds;
  final int sideShowSeconds;
  final Duration disconnectedTurn;
  final Duration disconnectGrace;
  final Duration quickPlayStartDelay;
  final Duration nextHandDelay;
  final int maxStrikes;

  final rooms = <String, Room>{};
  final _roomOf = <String, String>{};
  final _conns = <String, Connection>{};

  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  // ---------------------------------------------------------------- connections

  void onConnect(Connection c) {
    final old = _conns[c.user.id];
    _conns[c.user.id] = c;
    if (old != null && old != c) old.close(4001, 'Signed in elsewhere');

    final code = _roomOf[c.user.id];
    c.send({'type': 'HELLO', 'userId': c.user.id, 'name': c.user.name, 'balance': c.user.balance, 'roomCode': code});
    final room = code == null ? null : rooms[code];
    final member = room?.members[c.user.id];
    if (room == null || member == null) {
      if (code != null) _roomOf.remove(c.user.id);
      return;
    }
    member.dropTimer?.cancel();
    member.conn = c;
    _roomEvent(room, 'PLAYER_RECONNECTED', {'userId': c.user.id});
    _sendRoomState(room);
    _sendGame(room, member, const []);
    // The turn timer may have been shortened while they were away.
    if (room.inProgress) _schedule(room);
  }

  void onDisconnect(Connection c) {
    if (_conns[c.user.id] == c) _conns.remove(c.user.id);
    final room = _roomFor(c.user.id);
    final member = room?.members[c.user.id];
    if (room == null || member == null || member.conn != c) return;
    member.conn = null;
    _roomEvent(room, 'PLAYER_DISCONNECTED', {'userId': c.user.id});
    _sendRoomState(room);
    member.dropTimer?.cancel();
    member.dropTimer = Timer(disconnectGrace, () => _dropMember(room, member));
    if (room.inProgress) _schedule(room); // shorter timer for absent players
  }

  void _dropMember(Room room, Member m) {
    if (m.connected) return;
    if (room.inProgress && _inHand(room, m.user.id)) {
      m.leaving = true;
      _schedule(room);
    } else {
      _removeMember(room, m);
    }
  }

  // ------------------------------------------------------------------ dispatch

  Future<void> handle(Connection c, Map<String, Object?> msg) async {
    final id = msg['id'];
    void result(bool ok, {String? error, Map<String, Object?> extra = const {}}) =>
        c.send({'type': 'RESULT', 'id': id, 'ok': ok, if (error != null) 'error': error, ...extra});

    try {
      switch (msg['type']) {
        case 'PING':
          c.send({'type': 'PONG', 'serverTime': DateTime.now().millisecondsSinceEpoch});
        case 'CREATE_ROOM':
          final err = _create(c, msg);
          result(err == null, error: err, extra: {'roomCode': _roomOf[c.user.id]});
        case 'JOIN_ROOM':
          final err = _join(c, msg['code']);
          result(err == null, error: err, extra: {'roomCode': _roomOf[c.user.id]});
        case 'QUICK_PLAY':
          final err = _quickPlay(c, msg['players']);
          result(err == null, error: err, extra: {'roomCode': _roomOf[c.user.id]});
        case 'LEAVE_ROOM':
          final err = _leave(c);
          result(err == null, error: err);
        case 'START_GAME':
          final err = _hostStart(c);
          result(err == null, error: err);
        case 'ACTION':
          await _action(c, msg);
        default:
          _strike(c, 1, 'UNKNOWN_TYPE');
          result(false, error: 'UNKNOWN_TYPE');
      }
    } catch (e) {
      // Never leak internals to clients.
      result(false, error: 'SERVER_ERROR');
    }
  }

  void strike(Connection c, double amount, String reason) => _strike(c, amount, reason);

  void _strike(Connection c, double amount, String reason) {
    c.strikes += amount;
    if (c.strikes >= maxStrikes) {
      c.send({'type': 'ERROR', 'code': 'TOO_MANY_VIOLATIONS'});
      c.close(WebSocketStatus.policyViolation, 'Too many violations');
    }
  }

  // --------------------------------------------------------------------- rooms

  Room? _roomFor(String userId) {
    final code = _roomOf[userId];
    return code == null ? null : rooms[code];
  }

  String _newCode() {
    final r = SecureRandomSource();
    while (true) {
      final code = String.fromCharCodes([for (var i = 0; i < 7; i++) _codeAlphabet.codeUnitAt(r.nextInt(_codeAlphabet.length))]);
      if (!rooms.containsKey(code)) return code;
    }
  }

  String? _create(Connection c, Map<String, Object?> msg, {bool isPublic = false, bool autoStart = false}) {
    if (_roomOf.containsKey(c.user.id)) return 'ALREADY_IN_ROOM';
    final max = msg['maxPlayers'];
    final boot = msg['boot'] ?? 100;
    if (max is! int || max < 2 || max > 6) return 'BAD_MAX_PLAYERS';
    if (boot is! int || boot < 10 || boot > 100000) return 'BAD_BOOT';
    if (c.user.balance < boot) return 'INSUFFICIENT_CHIPS';
    final room = Room(_newCode(), c.user.id, max, boot, isPublic: isPublic, autoStart: autoStart);
    rooms[room.code] = room;
    _addMember(room, c);
    _roomEvent(room, 'ROOM_CREATED', {'code': room.code});
    _sendRoomState(room);
    return null;
  }

  String? _join(Connection c, Object? rawCode) {
    if (rawCode is! String || rawCode.length > 12) return 'BAD_CODE';
    if (_roomOf.containsKey(c.user.id)) return 'ALREADY_IN_ROOM';
    final room = rooms[rawCode.trim().toUpperCase()];
    if (room == null) return 'ROOM_NOT_FOUND';
    if (room.members.length >= room.maxPlayers) return 'ROOM_FULL';
    if (room.inProgress) return 'GAME_IN_PROGRESS';
    _addMember(room, c);
    _roomEvent(room, 'PLAYER_JOINED', {'userId': c.user.id, 'name': c.user.name});
    _sendRoomState(room);
    _maybeAutoStart(room);
    return null;
  }

  String? _quickPlay(Connection c, Object? players) {
    if (players is! int || players < 2 || players > 6) return 'BAD_MAX_PLAYERS';
    if (_roomOf.containsKey(c.user.id)) return 'ALREADY_IN_ROOM';
    const boot = 100;
    if (c.user.balance < boot) return 'INSUFFICIENT_CHIPS';
    for (final room in rooms.values) {
      if (room.isPublic && room.maxPlayers == players && !room.inProgress && room.members.length < players && room.boot == boot) {
        return _join(c, room.code);
      }
    }
    return _create(c, {'maxPlayers': players, 'boot': boot}, isPublic: true, autoStart: true);
  }

  void _addMember(Room room, Connection c) {
    final m = Member(c.user)..conn = c;
    room.members[c.user.id] = m;
    _roomOf[c.user.id] = room.code;
  }

  String? _leave(Connection c) {
    final room = _roomFor(c.user.id);
    final m = room?.members[c.user.id];
    if (room == null || m == null) return 'NOT_IN_ROOM';
    if (room.inProgress && _inHand(room, c.user.id)) {
      m.leaving = true; // folds on their next turn, removed at settlement
      _schedule(room);
    } else {
      _removeMember(room, m);
    }
    return null;
  }

  void _removeMember(Room room, Member m) {
    m.dropTimer?.cancel();
    room.members.remove(m.user.id);
    room.seenActions.remove(m.user.id);
    _roomOf.remove(m.user.id);
    m.conn?.send({'type': 'ROOM_LEFT', 'code': room.code});
    if (room.members.isEmpty) {
      room.turnTimer?.cancel();
      room.startTimer?.cancel();
      rooms.remove(room.code);
      return;
    }
    if (room.hostId == m.user.id) {
      room.hostId = room.members.values.firstWhere((x) => x.connected, orElse: () => room.members.values.first).user.id;
      _roomEvent(room, 'HOST_CHANGED', {'userId': room.hostId});
    }
    _roomEvent(room, 'PLAYER_LEFT', {'userId': m.user.id});
    _sendRoomState(room);
  }

  bool _inHand(Room room, String userId) =>
      room.game != null && room.game!.players.any((p) => p.id == userId);

  void _roomEvent(Room room, String event, Map<String, Object?> data) {
    final msg = {'type': 'ROOM_EVENT', 'event': event, 'code': room.code, ...data};
    for (final m in room.members.values) {
      m.conn?.send(msg);
    }
  }

  void _sendRoomState(Room room) {
    final msg = {
      'type': 'ROOM_STATE',
      'code': room.code,
      'hostId': room.hostId,
      'maxPlayers': room.maxPlayers,
      'boot': room.boot,
      'status': room.inProgress ? 'playing' : 'waiting',
      'players': [
        for (final m in room.members.values)
          {'id': m.user.id, 'name': m.user.name, 'chips': m.user.balance, 'connected': m.connected, 'host': m.user.id == room.hostId},
      ],
    };
    for (final m in room.members.values) {
      m.conn?.send(msg);
    }
  }

  // ---------------------------------------------------------------------- game

  String? _hostStart(Connection c) {
    final room = _roomFor(c.user.id);
    if (room == null) return 'NOT_IN_ROOM';
    if (room.hostId != c.user.id) return 'NOT_HOST';
    return _startHand(room);
  }

  void _maybeAutoStart(Room room) {
    if (!room.autoStart || room.inProgress || room.startTimer != null) return;
    if (room.members.length < room.maxPlayers) return;
    room.startTimer = Timer(quickPlayStartDelay, () {
      room.startTimer = null;
      if (rooms[room.code] == room && !room.inProgress) _startHand(room);
    });
  }

  String? _startHand(Room room) {
    if (room.inProgress) return 'GAME_IN_PROGRESS';
    final eligible = [
      for (final m in room.members.values)
        if (!m.leaving && m.user.balance >= room.boot) m
    ];
    if (eligible.length < 2) return 'NOT_ENOUGH_PLAYERS';

    room.dealerIndex = (room.dealerIndex + 1) % eligible.length;
    final result = TeenPattiEngine.startGame(
      players: [
        for (final m in eligible) PlayerState(id: m.user.id, name: m.user.name, chips: m.user.balance),
      ],
      settings: GameSettings(bootAmount: room.boot, turnSeconds: turnSeconds),
      random: random,
      dealerIndex: room.dealerIndex,
    );
    room.gameId = randomHex(6);
    room.startChips = {for (final m in eligible) m.user.id: m.user.balance};
    room.seenActions.clear();
    room.game = result.state;
    _afterChange(room, result.events);
    _sendRoomState(room);
    return null;
  }

  static int _total(GameState g) =>
      g.players.fold<int>(0, (a, p) => a + p.chips) + (g.isFinished ? 0 : g.pot);

  Future<void> _action(Connection c, Map<String, Object?> msg) async {
    final room = _roomFor(c.user.id);
    final actionId = msg['actionId'];
    if (actionId is! String || actionId.isEmpty || actionId.length > 64) {
      _strike(c, 1, 'BAD_ACTION_ID');
      c.send({'type': 'ACK', 'actionId': null, 'ok': false, 'error': 'BAD_ACTION_ID'});
      return;
    }
    void ack(bool ok, [String? error]) =>
        c.send({'type': 'ACK', 'actionId': actionId, 'ok': ok, if (error != null) 'error': error});

    if (room == null) return ack(false, 'NOT_IN_ROOM');

    // Idempotency: a retried action (e.g. after reconnect) is never applied twice.
    final cache = room.seenActions.putIfAbsent(c.user.id, () => {});
    final cached = cache[actionId];
    if (cached != null) {
      c.send(cached);
      return;
    }
    Map<String, Object?> remember(bool ok, [String? error]) {
      final a = {'type': 'ACK', 'actionId': actionId, 'ok': ok, if (error != null) 'error': error, 'duplicate': true};
      cache[actionId] = a;
      if (cache.length > 200) cache.remove(cache.keys.first);
      return a;
    }

    final raw = msg['action'];
    GameAction action;
    try {
      if (raw is! Map) throw const FormatException('action must be an object');
      // The acting player is always the authenticated user, never a client claim.
      action = GameAction.fromJson({...raw.cast<String, Object?>(), 'playerId': c.user.id});
    } on FormatException {
      _strike(c, 1, 'BAD_ACTION');
      remember(false, 'BAD_ACTION');
      return ack(false, 'BAD_ACTION');
    } on TypeError {
      _strike(c, 1, 'BAD_ACTION');
      remember(false, 'BAD_ACTION');
      return ack(false, 'BAD_ACTION');
    }

    final game = room.game;
    if (game == null || game.isFinished) {
      remember(false, 'NO_GAME');
      return ack(false, 'NO_GAME');
    }

    try {
      final result = TeenPattiEngine.apply(game, action);
      remember(true);
      unawaited(store.logAction(ActionLogEntry(
          at: DateTime.now(), userId: c.user.id, roomCode: room.code, actionId: actionId, action: action.toJson(), accepted: true)));
      ack(true);
      room.game = result.state;
      _afterChange(room, result.events, before: game);
    } on InvalidActionException catch (e) {
      _strike(c, 0.25, 'INVALID_ACTION');
      remember(false, e.message);
      unawaited(store.logAction(ActionLogEntry(
          at: DateTime.now(), userId: c.user.id, roomCode: room.code, actionId: actionId, action: action.toJson(), accepted: false, error: e.message)));
      ack(false, e.message);
    }
  }

  void _afterChange(Room room, List<GameEvent> events, {GameState? before}) {
    final g = room.game!;
    // Impossible-state check: chips may only move between players and the pot.
    final expected = before != null ? _total(before) : room.startChips.values.fold<int>(0, (a, b) => a + b);
    if (_total(g) != expected) {
      _abortHand(room);
      return;
    }
    room.seq++;
    if (g.isFinished) {
      room.turnTimer?.cancel();
      room.deadline = null;
    } else {
      _schedule(room, broadcast: false); // arm first so GAME_STATE carries the deadline
    }
    for (final m in room.members.values) {
      _sendGame(room, m, events);
    }
    if (g.isFinished) _settle(room);
  }

  /// Safety net: restore everyone's chips and drop the hand.
  void _abortHand(Room room) {
    room.turnTimer?.cancel();
    room.game = null;
    for (final m in room.members.values) {
      m.conn?.send({'type': 'ERROR', 'code': 'GAME_ABORTED'});
    }
    _sendRoomState(room);
  }

  void _sendGame(Room room, Member m, List<GameEvent> events) {
    final g = room.game;
    final conn = m.conn;
    if (g == null || conn == null) return;
    conn.send({
      'type': 'GAME_STATE',
      'seq': room.seq,
      'state': g.redactedFor(m.user.id).toJson(),
      'events': [for (final e in events) e.toJson()],
      'deadlineMs': room.deadline?.millisecondsSinceEpoch,
      'serverTime': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _schedule(Room room, {bool broadcast = true}) {
    room.turnTimer?.cancel();
    room.deadline = null;
    final g = room.game;
    if (g == null || g.isFinished) return;

    final pending = g.pendingSideShow;
    final String actorId = pending?.responderId ?? g.currentPlayer.id;
    final GameAction fallback = pending != null ? SideShowResponse(actorId, accept: false) : Fold(actorId);
    var limit = Duration(seconds: pending != null ? sideShowSeconds : turnSeconds);

    final m = room.members[actorId];
    if (m == null || m.leaving) {
      limit = const Duration(milliseconds: 200);
    } else if (!m.connected && disconnectedTurn < limit) {
      limit = disconnectedTurn;
    }

    room.deadline = DateTime.now().add(limit);
    room.turnTimer = Timer(limit, () => _serverAction(room, g, fallback));
    // Without a fresh GAME_STATE, tell clients about the (possibly shortened) deadline.
    if (broadcast) {
      for (final mm in room.members.values) {
        _sendDeadline(room, mm);
      }
    }
  }

  void _sendDeadline(Room room, Member m) {
    m.conn?.send({
      'type': 'DEADLINE',
      'seq': room.seq,
      'deadlineMs': room.deadline?.millisecondsSinceEpoch,
      'serverTime': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _serverAction(Room room, GameState expected, GameAction action) {
    // Ignore a stale timer: the state moved on since it was armed.
    if (!identical(room.game, expected)) return;
    try {
      final result = TeenPattiEngine.apply(expected, action);
      room.game = result.state;
      _afterChange(room, result.events, before: expected);
    } on InvalidActionException {
      // Nothing sensible to do.
    }
  }

  void _settle(Room room) {
    final g = room.game!;
    final id = room.gameId;
    for (final p in g.players) {
      final m = room.members[p.id];
      final delta = p.chips - (room.startChips[p.id] ?? p.chips);
      m?.user.balance = p.chips;
      unawaited(store.setBalance(p.id, p.chips));
      unawaited(store.addTransaction(TransactionEntry(DateTime.now(), p.id, delta, delta >= 0 ? 'WIN' : 'LOSS', id)));
    }
    unawaited(store.saveGame(GameHistoryEntry(
      id: id,
      roomCode: room.code,
      at: DateTime.now(),
      playerIds: [for (final p in g.players) p.id],
      winnerIds: g.winnerIds,
      pot: g.pot,
      handName: g.winningHandName,
    )));

    for (final m in room.members.values.toList()) {
      if (m.leaving) _removeMember(room, m);
    }
    if (!rooms.containsKey(room.code)) return;
    _sendRoomState(room);

    if (room.autoStart) {
      room.startTimer?.cancel();
      room.startTimer = Timer(nextHandDelay, () {
        room.startTimer = null;
        if (rooms[room.code] == room && !room.inProgress) _startHand(room);
      });
    }
  }

  /// Cancels all timers (used by tests and graceful shutdown).
  void dispose() {
    for (final r in rooms.values) {
      r.turnTimer?.cancel();
      r.startTimer?.cancel();
      for (final m in r.members.values) {
        m.dropTimer?.cancel();
      }
    }
    rooms.clear();
  }
}
