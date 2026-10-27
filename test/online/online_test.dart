import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teen_patti/core/errors/app_failure.dart';
import 'package:teen_patti/core/network/connection_status.dart';
import 'package:teen_patti/core/storage/key_value_store.dart';
import 'package:teen_patti/features/game/data/game_repository.dart';
import 'package:teen_patti/features/online/online_controller.dart';
import 'package:teen_patti_engine/teen_patti_engine.dart';
import 'package:teen_patti_server/server.dart';

/// Real WebSockets against an in-process server (plain `test`, so real async).
Future<void> until(bool Function() cond, {Duration timeout = const Duration(seconds: 10), String? what}) async {
  final end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('Timed out waiting for ${what ?? 'condition'}');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

ProviderContainer player(TeenPattiServer server, String name) {
  final store = MemoryStore();
  final c = ProviderContainer(overrides: [
    keyValueStoreProvider.overrideWithValue(store),
    onlineBackoffProvider.overrideWithValue(const Duration(milliseconds: 40)),
  ]);
  c.read(serverUrlProvider.notifier).set('http://127.0.0.1:${server.port}');
  store.setString('profile.v1', '{"username":"$name","avatarIndex":0,"chips":10000}');
  return c;
}

void main() {
  late InMemoryStore store;
  late RoomManager manager;
  late TeenPattiServer server;
  final containers = <ProviderContainer>[];

  setUp(() async {
    store = InMemoryStore();
    manager = RoomManager(store: store, random: SeededRandomSource(11), turnSeconds: 30);
    server = await TeenPattiServer.start(store: store, manager: manager);
  });

  tearDown(() async {
    for (final c in containers) {
      await c.read(onlineProvider.notifier).disconnect();
      c.dispose();
    }
    containers.clear();
    await server.close();
  });

  ProviderContainer newPlayer(String name) {
    final c = player(server, name);
    containers.add(c);
    return c;
  }

  Future<(ProviderContainer, ProviderContainer, GameRepository, GameRepository)> startTwoPlayerGame() async {
    final a = newPlayer('Alice');
    final b = newPlayer('Bob');
    final code = await a.read(onlineProvider.notifier).createRoom(maxPlayers: 4);
    expect(code, isNotNull);
    expect(await b.read(onlineProvider.notifier).joinRoom(code!), code);
    await until(() => a.read(onlineProvider).room?.players.length == 2, what: 'both in room');
    expect(a.read(onlineProvider).isHost, isTrue);
    expect(b.read(onlineProvider).isHost, isFalse);

    expect(await a.read(onlineProvider.notifier).startGame(), isTrue);
    await until(() => b.read(onlineProvider).room?.playing == true, what: 'room playing');
    return (a, b, a.read(onlineProvider.notifier).repository!, b.read(onlineProvider.notifier).repository!);
  }

  test('create, join, start: both clients get a redacted authoritative state', () async {
    final (_, _, repoA, repoB) = await startTwoPlayerGame();
    final ua = await repoA.updates.firstWhere((u) => u.state.status == GameStatus.inProgress);
    final ub = await repoB.updates.firstWhere((u) => u.state.status == GameStatus.inProgress);

    expect(ua.events.map((e) => e.type), contains(GameEvent.cardsDealt)); // replayed to late listeners
    expect(ua.state.pot, 200);
    expect(ua.state.players.every((p) => p.hand.isEmpty), isTrue, reason: 'cards are hidden until seen');
    expect(ub.turnDeadline, isNotNull);
    expect(ub.state.currentPlayer.id, ua.state.currentPlayer.id);
  });

  test('actions go through the server; out-of-turn is rejected, duplicates are not applied twice', () async {
    final (_, _, repoA, repoB) = await startTwoPlayerGame();
    final first = await repoA.updates.firstWhere((u) => u.state.status == GameStatus.inProgress);
    final actorId = first.state.currentPlayer.id;
    final actor = repoA.localPlayerId == actorId ? repoA : repoB;
    final idle = identical(actor, repoA) ? repoB : repoA;

    await expectLater(idle.send(Call(idle.localPlayerId)), throwsA(isA<InvalidActionException>()));
    await actor.send(Call(actor.localPlayerId));
    final after = await idle.updates.firstWhere((u) => u.state.pot == 300);
    expect(after.events.map((e) => e.type), contains(GameEvent.playerBet));

    // The player can look at their own cards; the opponent still sees nothing.
    await idle.send(SeeCards(idle.localPlayerId));
    final seen = await idle.updates.firstWhere((u) => u.state.playerById(idle.localPlayerId).hand.length == 3);
    expect(seen.state.players.where((p) => p.id != idle.localPlayerId).every((p) => p.hand.isEmpty), isTrue);
  });

  test('reconnects after a connection drop and resumes the same hand without duplicate bets', () async {
    final (a, b, repoA, repoB) = await startTwoPlayerGame();
    final first = await repoA.updates.firstWhere((u) => u.state.status == GameStatus.inProgress);
    final actor = repoA.localPlayerId == first.state.currentPlayer.id ? repoA : repoB;
    await actor.send(Raise(actor.localPlayerId));
    await repoB.updates.firstWhere((u) => u.state.stake == 200);

    // Network drops: server goes away but its state survives.
    final port = server.port;
    await server.close(disposeManager: false);
    await until(() => a.read(onlineProvider).connection == ConnectionStatus.reconnecting, what: 'reconnecting');
    expect(b.read(onlineProvider).connection, ConnectionStatus.reconnecting);

    server = await TeenPattiServer.start(port: port, store: store, manager: manager);
    await until(
        () => a.read(onlineProvider).connection == ConnectionStatus.connected &&
            b.read(onlineProvider).connection == ConnectionStatus.connected,
        what: 'both reconnected');

    // Still in the same room with the same hand; nothing was bet twice.
    await until(() => a.read(onlineProvider).room != null && b.read(onlineProvider).room != null, what: 'room restored');
    final resumed = await repoA.updates.firstWhere((u) => u.connection == ConnectionStatus.connected);
    expect(resumed.state.status, GameStatus.inProgress);
    expect(resumed.state.stake, 200);
    expect(resumed.state.pot, 200 + 200);

    // And play continues.
    final turn = resumed.state.currentPlayer.id;
    final next = repoA.localPlayerId == turn ? repoA : repoB;
    await next.send(Fold(next.localPlayerId));
    final end = await repoA.updates.firstWhere((u) => u.state.isFinished);
    expect(end.state.winnerIds, [actor.localPlayerId]);
  });

  test('friendly errors for bad room codes and unreachable servers', () async {
    final a = newPlayer('Alice');
    expect(await a.read(onlineProvider.notifier).joinRoom('NOPE123'), isNull);
    final f = a.read(onlineProvider).failure!;
    expect(f.kind, FailureKind.invalidAction);
    expect(onlineErrorText(f), 'No room with that code.');

    final offline = ProviderContainer(overrides: [keyValueStoreProvider.overrideWithValue(MemoryStore())]);
    containers.add(offline);
    await offline.read(serverUrlProvider.notifier).set('http://127.0.0.1:1');
    expect(await offline.read(onlineProvider.notifier).quickPlay(3), isNull);
    final failure = offline.read(onlineProvider).failure!;
    expect(failure.kind, FailureKind.noInternet);
    expect(failure.message, isNot(contains('Exception')));
    expect(offline.read(onlineProvider).connection, ConnectionStatus.offline);
  });

  test('a server restart that forgets sessions starts a fresh identity instead of looping forever', () async {
    final a = newPlayer('Alice');
    final code = await a.read(onlineProvider.notifier).createRoom(maxPlayers: 3);
    expect(code, isNotNull);
    final oldId = a.read(onlineProvider).userId;

    final port = server.port;
    await server.close();
    final freshStore = InMemoryStore();
    server = await TeenPattiServer.start(
        port: port, store: freshStore, manager: RoomManager(store: freshStore, random: SeededRandomSource(1)));

    await until(
        () => a.read(onlineProvider).connection == ConnectionStatus.connected &&
            a.read(onlineProvider).userId != oldId,
        timeout: const Duration(seconds: 15),
        what: 'fresh session');
    expect(a.read(onlineProvider).room, isNull);
    // The new identity can play normally.
    expect(await a.read(onlineProvider.notifier).createRoom(maxPlayers: 3), isNotNull);
  });
}
