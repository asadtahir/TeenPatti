import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:teen_patti_engine/teen_patti_engine.dart';
import 'package:teen_patti_server/server.dart';
import 'package:teen_patti_server/src/rate_limiter.dart';
import 'package:test/test.dart';

typedef Json = Map<String, Object?>;

class Client {
  Client._(this.server, this.userId, this.name, this.token);
  final TeenPattiServer server;
  final String userId;
  final String name;
  final String token;
  WebSocket? ws;
  final log = <Json>[];
  final _waiters = <(bool Function(Json), Completer<Json>, int)>[];
  int? closeCode;
  int _reqId = 0;

  static Future<Client> register(TeenPattiServer server, String name) async {
    final http = HttpClient();
    final req = await http.postUrl(Uri.parse('http://127.0.0.1:${server.port}/auth/guest'));
    req.write(jsonEncode({'name': name}));
    final res = await req.close();
    final body = jsonDecode(await utf8.decoder.bind(res).join()) as Json;
    http.close();
    return Client._(server, body['userId'] as String, body['name'] as String, body['token'] as String);
  }

  static Future<Client> connect(TeenPattiServer server, String name) async {
    final c = await register(server, name);
    await c.open();
    return c;
  }

  Future<void> open() async {
    closeCode = null;
    final mark = log.length;
    final socket = await WebSocket.connect('ws://127.0.0.1:${server.port}/ws?token=$token');
    ws = socket;
    socket.listen((d) {
      final m = (jsonDecode(d as String) as Map).cast<String, Object?>();
      log.add(m);
      for (final w in _waiters.toList()) {
        if (w.$1(m)) {
          _waiters.remove(w);
          w.$2.complete(m);
        }
      }
    }, onDone: () => closeCode = socket.closeCode);
    await waitFor((m) => m['type'] == 'HELLO', from: mark);
  }

  /// Waits for a message matching [test], looking at messages after index [from] first.
  Future<Json> waitFor(bool Function(Json) test, {int from = 0, Duration timeout = const Duration(seconds: 5)}) {
    for (var i = from; i < log.length; i++) {
      if (test(log[i])) return Future.value(log[i]);
    }
    final c = Completer<Json>();
    final w = (test, c, from);
    _waiters.add(w);
    return c.future.timeout(timeout, onTimeout: () {
      _waiters.remove(w);
      throw TimeoutException('No matching message. Log: ${log.map((m) => m['type']).toList()}');
    });
  }

  void send(Json m) => ws!.add(jsonEncode(m));

  Future<Json> request(Json m) {
    final id = 'r${_reqId++}';
    final from = log.length;
    send({...m, 'id': id});
    return waitFor((x) => x['type'] == 'RESULT' && x['id'] == id, from: from);
  }

  Future<Json> act(GameAction a, {String? actionId}) {
    final id = actionId ?? 'a${_reqId++}';
    final from = log.length;
    send({'type': 'ACTION', 'actionId': id, 'action': a.toJson()});
    return waitFor((x) => x['type'] == 'ACK' && x['actionId'] == id, from: from);
  }

  Json? get latestGame => log.cast<Json?>().lastWhere((m) => m!['type'] == 'GAME_STATE', orElse: () => null);

  GameState get state => GameState.fromJson((latestGame!['state'] as Map).cast<String, Object?>());

  Future<GameState> nextState({int? minSeq, int from = 0}) async {
    final m = await waitFor(
        (x) => x['type'] == 'GAME_STATE' && (minSeq == null || (x['seq'] as int) >= minSeq),
        from: from);
    return GameState.fromJson((m['state'] as Map).cast<String, Object?>());
  }

  Future<void> close() async => ws?.close();
}

Future<TeenPattiServer> boot({RoomManager Function(Store)? manager, Store? store}) async {
  final s = store ?? InMemoryStore();
  return TeenPattiServer.start(
    store: s,
    manager: manager?.call(s) ??
        RoomManager(store: s, random: SeededRandomSource(42), turnSeconds: 30),
  );
}

/// Creates a room with [n] players who have all joined; returns (clients, code).
Future<(List<Client>, String)> table(TeenPattiServer server, int n) async {
  final clients = [for (var i = 0; i < n; i++) await Client.connect(server, 'P$i')];
  final created = await clients[0].request({'type': 'CREATE_ROOM', 'maxPlayers': 6, 'boot': 100});
  final code = created['roomCode'] as String;
  for (final c in clients.skip(1)) {
    final r = await c.request({'type': 'JOIN_ROOM', 'code': code});
    expect(r['ok'], isTrue, reason: '$r');
  }
  return (clients, code);
}

Client byId(List<Client> cs, String id) => cs.firstWhere((c) => c.userId == id);

void main() {
  late TeenPattiServer server;
  tearDown(() async => server.close());

  group('auth', () {
    test('guest registration and websocket handshake', () async {
      server = await boot();
      final c = await Client.connect(server, 'Alice');
      final hello = c.log.first;
      expect(hello['userId'], c.userId);
      expect(hello['balance'], 10000);
      await c.close();
    });

    test('name is sanitised', () async {
      server = await boot();
      final c = await Client.register(server, '<b>Evil\u0000Name</b>${'x' * 50}');
      expect(c.name.contains('<'), isFalse);
      expect(c.name.length, lessThanOrEqualTo(20));
    });

    test('websocket without or with a bad token is refused', () async {
      server = await boot();
      expect(WebSocket.connect('ws://127.0.0.1:${server.port}/ws'), throwsA(isA<WebSocketException>()));
      expect(WebSocket.connect('ws://127.0.0.1:${server.port}/ws?token=nope'), throwsA(isA<WebSocketException>()));
    });

    test('server restart invalidates in-memory sessions, client must re-register', () async {
      server = await boot();
      final c = await Client.register(server, 'A');
      await server.close();
      server = await boot();
      final fresh = Client.register(server, 'A');
      await expectLater(fresh, completes);
      final old = Uri.parse('ws://127.0.0.1:${server.port}/ws?token=${c.token}');
      expect(WebSocket.connect(old.toString()), throwsA(isA<WebSocketException>()));
    });
  });

  group('rooms', () {
    test('create, join, leave, host transfer', () async {
      server = await boot();
      final (cs, code) = await table(server, 3);
      expect(code.length, 7);
      final state = await cs[0].waitFor((m) => m['type'] == 'ROOM_STATE' && (m['players'] as List).length == 3);
      expect(state['hostId'], cs[0].userId);

      final mark = cs[1].log.length;
      final left = await cs[0].request({'type': 'LEAVE_ROOM'});
      expect(left['ok'], isTrue);
      final after = await cs[1].waitFor((m) => m['type'] == 'ROOM_STATE' && (m['players'] as List).length == 2, from: mark);
      expect(after['hostId'], isNot(cs[0].userId));
    });

    test('rejects unknown, full and double joins', () async {
      server = await boot();
      final (cs, code) = await table(server, 2);
      expect((await cs[1].request({'type': 'JOIN_ROOM', 'code': code}))['error'], 'ALREADY_IN_ROOM');
      final out = await Client.connect(server, 'Out');
      expect((await out.request({'type': 'JOIN_ROOM', 'code': 'NOPE123'}))['error'], 'ROOM_NOT_FOUND');
      expect((await out.request({'type': 'JOIN_ROOM', 'code': 12345}))['error'], 'BAD_CODE');

      final small = await cs[0].request({'type': 'LEAVE_ROOM'});
      expect(small['ok'], isTrue);
      final h = await Client.connect(server, 'H');
      final created = await h.request({'type': 'CREATE_ROOM', 'maxPlayers': 2, 'boot': 100});
      final c2 = await Client.connect(server, 'J1');
      final c3 = await Client.connect(server, 'J2');
      await c2.request({'type': 'JOIN_ROOM', 'code': created['roomCode']});
      expect((await c3.request({'type': 'JOIN_ROOM', 'code': created['roomCode']}))['error'], 'ROOM_FULL');
    });

    test('create validates parameters', () async {
      server = await boot();
      final c = await Client.connect(server, 'A');
      expect((await c.request({'type': 'CREATE_ROOM', 'maxPlayers': 9, 'boot': 100}))['error'], 'BAD_MAX_PLAYERS');
      expect((await c.request({'type': 'CREATE_ROOM', 'maxPlayers': 4, 'boot': -5}))['error'], 'BAD_BOOT');
      expect((await c.request({'type': 'CREATE_ROOM', 'maxPlayers': 4, 'boot': 999999}))['error'], 'BAD_BOOT');
      expect((await c.request({'type': 'CREATE_ROOM', 'maxPlayers': 4, 'boot': 5000}))['ok'], isTrue);
    });

    test('only the host can start; needs two players', () async {
      server = await boot();
      final (cs, _) = await table(server, 2);
      expect((await cs[1].request({'type': 'START_GAME'}))['error'], 'NOT_HOST');
      final solo = await Client.connect(server, 'Solo');
      await solo.request({'type': 'CREATE_ROOM', 'maxPlayers': 3, 'boot': 100});
      expect((await solo.request({'type': 'START_GAME'}))['error'], 'NOT_ENOUGH_PLAYERS');
    });

    test('quick play matches players and auto-starts when full', () async {
      final s = InMemoryStore();
      server = await boot(
        store: s,
        manager: (st) => RoomManager(store: st, random: SeededRandomSource(1), quickPlayStartDelay: const Duration(milliseconds: 20)),
      );
      final a = await Client.connect(server, 'A');
      final b = await Client.connect(server, 'B');
      final ra = await a.request({'type': 'QUICK_PLAY', 'players': 2});
      final rb = await b.request({'type': 'QUICK_PLAY', 'players': 2});
      expect(ra['roomCode'], rb['roomCode']);
      final st = await a.nextState();
      expect(st.status, GameStatus.inProgress);
      expect(st.players.length, 2);
    });
  });

  group('server-authoritative game', () {
    test('deals 3 cards each, hides every hand until seen', () async {
      server = await boot();
      final (cs, _) = await table(server, 3);
      expect((await cs[0].request({'type': 'START_GAME'}))['ok'], isTrue);
      for (final c in cs) {
        final s = await c.nextState();
        expect(s.pot, 300);
        expect(s.players.every((p) => p.hand.isEmpty), isTrue, reason: 'no cards leak before seeing');
      }
      final me = cs[0];
      final mark = me.log.length;
      expect((await me.act(const SeeCards('ignored')))['ok'], isTrue);
      final mine = await me.nextState(from: mark);
      final own = mine.playerById(me.userId);
      expect(own.hand.length, 3);
      expect(mine.players.where((p) => p.id != me.userId).every((p) => p.hand.isEmpty), isTrue);
      // Others still see nothing of my hand.
      final other = await cs[1].nextState(minSeq: 2);
      expect(other.playerById(me.userId).seen, isTrue);
      expect(other.playerById(me.userId).hand, isEmpty);
    });

    test('betting, turn order, forged player ids and duplicates', () async {
      server = await boot();
      final (cs, _) = await table(server, 3);
      await cs[0].request({'type': 'START_GAME'});
      var s = await cs[0].nextState();
      final actor = byId(cs, s.currentPlayer.id);
      final other = cs.firstWhere((c) => c != actor);

      // Out of turn is refused.
      final bad = await other.act(const Call('x'));
      expect(bad['ok'], isFalse);

      // Forging someone else's id is ignored: the server acts as the authenticated user.
      final forged = await other.act(Call(actor.userId));
      expect(forged['ok'], isFalse);
      expect(forged['error'], 'Not your turn');

      final ok = await actor.act(const Call('whatever'), actionId: 'bet-1');
      expect(ok['ok'], isTrue);
      s = await actor.nextState(minSeq: 2);
      expect(s.pot, 400);

      // Retrying the same actionId (e.g. after a reconnect) does not bet twice.
      final dup = await actor.act(const Call('whatever'), actionId: 'bet-1');
      expect(dup['ok'], isTrue);
      expect(dup['duplicate'], isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(actor.state.pot, 400);
      expect(actor.log.where((m) => m['type'] == 'GAME_STATE').length, 2);
    });

    test('malformed actions are rejected without crashing the server', () async {
      server = await boot();
      final (cs, _) = await table(server, 2);
      await cs[0].request({'type': 'START_GAME'});
      await cs[0].nextState();
      cs[0].send({'type': 'ACTION', 'actionId': 'm1', 'action': 'DROP TABLE'});
      expect((await cs[0].waitFor((m) => m['type'] == 'ACK' && m['actionId'] == 'm1'))['error'], 'BAD_ACTION');
      cs[0].send({'type': 'ACTION', 'actionId': 'm2', 'action': {'type': 'HACK'}});
      expect((await cs[0].waitFor((m) => m['type'] == 'ACK' && m['actionId'] == 'm2'))['error'], 'BAD_ACTION');
      cs[0].send({'type': 'ACTION', 'action': {'type': 'CALL'}});
      expect((await cs[0].waitFor((m) => m['type'] == 'ACK' && m['ok'] == false && m['actionId'] == null))['error'], 'BAD_ACTION_ID');
      expect((await cs[0].request({'type': 'PING'}).timeout(const Duration(seconds: 1), onTimeout: () => {'type': 'RESULT'}))['type'], 'RESULT');
    });

    test('full hand: last player standing wins, balances settle and chips are conserved', () async {
      final store = InMemoryStore();
      server = await boot(store: store);
      final (cs, _) = await table(server, 3);
      await cs[0].request({'type': 'START_GAME'});
      var s = await cs[0].nextState();

      // Everyone but the first player folds as their turn comes.
      final survivor = s.currentPlayer.id;
      while (!s.isFinished) {
        final actor = byId(cs, s.currentPlayer.id);
        final action = actor.userId == survivor ? Call(actor.userId) : Fold(actor.userId);
        if (actor.userId == survivor && s.activePlayers.length == 1) break;
        await actor.act(action);
        s = await cs[0].nextState(minSeq: (cs[0].latestGame!['seq'] as int) + 1);
      }
      expect(s.winnerIds, [survivor]);
      expect(s.showdown, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      final total = s.players.fold<int>(0, (a, p) => a + p.chips);
      expect(total, 30000);
      expect(store.transactions.fold<int>(0, (a, t) => a + t.delta), 0);
      expect(store.games.single.winnerIds, [survivor]);
      expect(store.actionLog.where((e) => e.accepted), isNotEmpty);
    });

    test('showdown reveals only the non-folded hands', () async {
      server = await boot();
      final (cs, _) = await table(server, 2);
      await cs[0].request({'type': 'START_GAME'});
      final s = await cs[0].nextState();
      final actor = byId(cs, s.currentPlayer.id);
      expect((await actor.act(Show(actor.userId)))['ok'], isTrue);
      final end = await cs[0].waitFor((m) => m['type'] == 'GAME_STATE' && (m['state'] as Map)['status'] == 'finished');
      final st = GameState.fromJson((end['state'] as Map).cast<String, Object?>());
      expect(st.showdown, isTrue);
      expect(st.players.every((p) => p.hand.length == 3), isTrue);
      expect(st.winningHandName, isNotNull);
    });

    test('turn timeout auto-folds the idle player', () async {
      final store = InMemoryStore();
      server = await boot(
        store: store,
        manager: (st) => RoomManager(store: st, random: SeededRandomSource(3), turnSeconds: 1),
      );
      final (cs, _) = await table(server, 2);
      await cs[0].request({'type': 'START_GAME'});
      final end = await cs[0].waitFor(
        (m) => m['type'] == 'GAME_STATE' && (m['state'] as Map)['status'] == 'finished',
        timeout: const Duration(seconds: 6),
      );
      final events = (end['events'] as List).cast<Json>();
      expect(events.map((e) => e['type']), contains(GameEvent.playerFolded));
    });

    test('GAME_STATE carries a turn deadline', () async {
      server = await boot();
      final (cs, _) = await table(server, 2);
      await cs[0].request({'type': 'START_GAME'});
      final m = await cs[0].waitFor((x) => x['type'] == 'GAME_STATE');
      final deadline = m['deadlineMs'] as int;
      expect(deadline, greaterThan(DateTime.now().millisecondsSinceEpoch));
    });
  });

  group('reconnection', () {
    test('player reconnects mid-hand and receives the current state; others are told', () async {
      server = await boot();
      final (cs, code) = await table(server, 3);
      await cs[0].request({'type': 'START_GAME'});
      var s = await cs[0].nextState();
      final actor = byId(cs, s.currentPlayer.id);
      await actor.act(const Call('x'));
      await cs[0].nextState(minSeq: 2);

      final dropped = cs[2];
      await dropped.ws!.close();
      await cs[0].waitFor((m) => m['type'] == 'ROOM_EVENT' && m['event'] == 'PLAYER_DISCONNECTED');

      final mark = dropped.log.length;
      await dropped.open();
      expect(dropped.log.lastWhere((m) => m['type'] == 'HELLO')['roomCode'], code);
      final roomState = await dropped.waitFor((m) => m['type'] == 'ROOM_STATE', from: mark);
      expect((roomState['players'] as List).length, 3);
      final game = await dropped.nextState(from: mark);
      expect(game.pot, 400);
      expect(game.status, GameStatus.inProgress);
      await cs[0].waitFor((m) => m['type'] == 'ROOM_EVENT' && m['event'] == 'PLAYER_RECONNECTED');
    });

    test('two players reconnect at the same time', () async {
      server = await boot();
      final (cs, _) = await table(server, 3);
      await cs[0].request({'type': 'START_GAME'});
      await cs[0].nextState();
      await Future.wait([cs[1].ws!.close(), cs[2].ws!.close()]);
      await cs[0].waitFor((m) => m['event'] == 'PLAYER_DISCONNECTED');
      await Future.wait([cs[1].open(), cs[2].open()]);
      for (final c in [cs[1], cs[2]]) {
        expect((await c.nextState()).players.length, 3);
      }
    });

    test('a retried action after reconnect is not applied twice', () async {
      server = await boot();
      final (cs, _) = await table(server, 2);
      await cs[0].request({'type': 'START_GAME'});
      final s = await cs[0].nextState();
      final actor = byId(cs, s.currentPlayer.id);
      await actor.act(const Raise('x'), actionId: 'raise-1');
      await actor.ws!.close();
      final mark = actor.log.length;
      await actor.open();
      final retry = await actor.act(const Raise('x'), actionId: 'raise-1');
      expect(retry['duplicate'], isTrue);
      final latest = await actor.nextState(from: mark);
      expect(latest.stake, 200); // doubled once, not twice
    });

    test('a disconnected player is auto-folded on their turn', () async {
      server = await boot(
        manager: (st) => RoomManager(
            store: st, random: SeededRandomSource(9), turnSeconds: 30, disconnectedTurn: const Duration(milliseconds: 150)),
      );
      final (cs, _) = await table(server, 3);
      await cs[0].request({'type': 'START_GAME'});
      final s = await cs[0].nextState();
      final absent = byId(cs, s.currentPlayer.id);
      final watcher = cs.firstWhere((c) => c != absent);
      await absent.ws!.close();
      final m = await watcher.waitFor(
        (x) => x['type'] == 'GAME_STATE' && ((x['events'] as List).cast<Json>().any((e) => e['type'] == 'PLAYER_FOLDED' && e['playerId'] == absent.userId)),
      );
      expect(m, isNotNull);
    });

    test('signing in from a second device kicks the first', () async {
      server = await boot();
      final a = await Client.connect(server, 'A');
      final second = await Client.register(server, 'ignored');
      final dup = Client._(server, a.userId, a.name, a.token);
      await dup.open();
      await a.waitFor((m) => false, timeout: const Duration(milliseconds: 300)).then((_) {}, onError: (_) {});
      expect(a.closeCode, 4001);
      expect(second.token, isNot(a.token));
    });

    test('leaving mid-hand folds the player and removes them after settlement', () async {
      server = await boot();
      final (cs, _) = await table(server, 3);
      await cs[0].request({'type': 'START_GAME'});
      var s = await cs[0].nextState();
      final leaver = cs.firstWhere((c) => c.userId != s.currentPlayer.id);
      expect((await leaver.request({'type': 'LEAVE_ROOM'}))['ok'], isTrue);
      // The leaver is folded automatically once their turn comes; play on until it ends.
      while (!s.isFinished) {
        final actor = byId(cs, s.currentPlayer.id);
        if (actor == leaver) {
          s = await cs[0].nextState(minSeq: (cs[0].latestGame!['seq'] as int) + 1);
          continue;
        }
        await actor.act(Fold(actor.userId));
        s = await cs[0].nextState(minSeq: (cs[0].latestGame!['seq'] as int) + 1);
      }
      await leaver.waitFor((m) => m['type'] == 'ROOM_LEFT');
    });
  });

  group('abuse protection', () {
    test('token bucket allows bursts then limits', () {
      var t = DateTime(2024);
      final rl = RateLimiter(capacity: 5, perSecond: 1, now: () => t);
      expect(List.generate(5, (_) => rl.allow()), everyElement(isTrue));
      expect(rl.allow(), isFalse);
      t = t.add(const Duration(seconds: 2));
      expect(rl.allow(), isTrue);
      expect(rl.allow(), isTrue);
      expect(rl.allow(), isFalse);
    });

    test('message floods are rate limited and eventually disconnected', () async {
      server = await boot();
      final c = await Client.connect(server, 'Flood');
      for (var i = 0; i < 400; i++) {
        try {
          c.send({'type': 'PING'});
        } catch (_) {
          break;
        }
      }
      await c.waitFor((m) => m['type'] == 'ERROR' && m['code'] == 'RATE_LIMITED');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(c.closeCode, WebSocketStatus.policyViolation);
    });

    test('garbage and oversize payloads are dropped, repeat offenders disconnected', () async {
      server = await boot();
      final c = await Client.connect(server, 'Bad');
      c.ws!.add('not json');
      c.ws!.add(jsonEncode({'type': 'PING'}));
      await c.waitFor((m) => m['type'] == 'PONG'); // still alive after one offence
      c.ws!.add('x' * 9000);
      c.ws!.add('x' * 9000);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(c.closeCode, WebSocketStatus.policyViolation);
    });

    test('unknown message types are refused', () async {
      server = await boot();
      final c = await Client.connect(server, 'U');
      expect((await c.request({'type': 'GIVE_ME_CHIPS', 'amount': 999999}))['error'], 'UNKNOWN_TYPE');
    });

    test('unauthenticated HTTP routes and methods are rejected', () async {
      server = await boot();
      final http = HttpClient();
      final get = await (await http.getUrl(Uri.parse('http://127.0.0.1:${server.port}/auth/guest'))).close();
      expect(get.statusCode, 405);
      final nope = await (await http.getUrl(Uri.parse('http://127.0.0.1:${server.port}/admin'))).close();
      expect(nope.statusCode, 404);
      final health = await (await http.getUrl(Uri.parse('http://127.0.0.1:${server.port}/health'))).close();
      expect(health.statusCode, 200);
      http.close();
    });

    test('tokens are stored hashed', () async {
      final store = InMemoryStore();
      server = await boot(store: store);
      final c = await Client.register(server, 'H');
      expect(await store.userByToken(c.token), isNotNull);
      expect(hashToken(c.token), isNot(c.token));
      expect(await store.userByToken(hashToken(c.token)), isNull);
    });
  });

  group('chips', () {
    test('a player without enough chips cannot create or start', () async {
      final store = InMemoryStore();
      server = await boot(store: store);
      final c = await Client.connect(server, 'Poor');
      expect((await c.request({'type': 'CREATE_ROOM', 'maxPlayers': 3, 'boot': 20000}))['error'], anyOf('BAD_BOOT', 'INSUFFICIENT_CHIPS'));
    });
  });
}
