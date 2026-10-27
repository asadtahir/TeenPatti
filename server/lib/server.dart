import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:teen_patti_engine/teen_patti_engine.dart';

import 'src/connection.dart';
import 'src/room_manager.dart';
import 'src/store.dart';

export 'src/room_manager.dart';
export 'src/store.dart';

/// HTTP + WebSocket front door.
///
/// * `GET  /health`
/// * `POST /auth/guest` `{ "name": "..." }` -> `{ userId, token, name, balance }`
/// * `GET  /ws?token=...` WebSocket upgrade
class TeenPattiServer {
  TeenPattiServer._(this._http, this.manager, this.store);

  final HttpServer _http;
  final RoomManager manager;
  final Store store;
  final _authHits = <String, List<DateTime>>{};
  final _sockets = <Connection>{};

  static const maxMessageBytes = 8 * 1024;

  int get port => _http.port;

  static Future<TeenPattiServer> start({
    int port = 0,
    String host = '127.0.0.1',
    Store? store,
    RoomManager? manager,
  }) async {
    final s = store ?? InMemoryStore();
    final m = manager ?? RoomManager(store: s);
    final http = await HttpServer.bind(host, port);
    final server = TeenPattiServer._(http, m, s);
    http.listen(server._onRequest);
    return server;
  }

  /// Stops accepting connections and closes every socket. Pass `disposeManager: false`
  /// to simulate a network drop (rooms survive and a new server can adopt [manager]).
  Future<void> close({bool disposeManager = true}) async {
    for (final c in _sockets.toList()) {
      await c.close(WebSocketStatus.goingAway, 'Server shutting down');
    }
    _sockets.clear();
    if (disposeManager) manager.dispose();
    await _http.close(force: true);
  }

  Future<void> _onRequest(HttpRequest req) async {
    try {
      switch (req.uri.path) {
        case '/health':
          req.response
            ..statusCode = 200
            ..write('ok');
          await req.response.close();
        case '/auth/guest':
          await _guestAuth(req);
        case '/ws':
          await _upgrade(req);
        default:
          req.response.statusCode = 404;
          await req.response.close();
      }
    } catch (_) {
      try {
        req.response.statusCode = 500;
        await req.response.close();
      } catch (_) {}
    }
  }

  bool _authAllowed(String ip) {
    final now = DateTime.now();
    final hits = _authHits.putIfAbsent(ip, () => [])
      ..removeWhere((t) => now.difference(t) > const Duration(minutes: 1));
    if (hits.length >= 30) return false;
    hits.add(now);
    return true;
  }

  Future<void> _guestAuth(HttpRequest req) async {
    final res = req.response;
    Future<void> json(int status, Object body) async {
      res
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await res.close();
    }

    if (req.method != 'POST') return json(405, {'error': 'METHOD_NOT_ALLOWED'});
    final ip = req.connectionInfo?.remoteAddress.address ?? 'unknown';
    if (!_authAllowed(ip)) return json(429, {'error': 'RATE_LIMITED'});
    if ((req.contentLength) > 1024) return json(413, {'error': 'TOO_LARGE'});

    var name = '';
    try {
      final body = await utf8.decoder.bind(req).join();
      if (body.length > 1024) {
        await json(413, {'error': 'TOO_LARGE'});
        return;
      }
      final decoded = body.isEmpty ? const <String, Object?>{} : jsonDecode(body);
      if (decoded is Map && decoded['name'] is String) name = decoded['name'] as String;
    } catch (_) {
      return json(400, {'error': 'BAD_REQUEST'});
    }
    name = name.replaceAll(RegExp(r'[\x00-\x1F\x7F<>]'), '').trim();
    if (name.length > 20) name = name.substring(0, 20);
    if (name.isEmpty) name = 'Player${SecureRandomSource().nextInt(9000) + 1000}';

    final (user, token) = await store.createUser(name);
    return json(200, {'userId': user.id, 'token': token, 'name': user.name, 'balance': user.balance});
  }

  Future<void> _upgrade(HttpRequest req) async {
    final token = req.uri.queryParameters['token'];
    final user = token == null || token.length > 128 ? null : await store.userByToken(token);
    if (user == null) {
      req.response.statusCode = 401;
      await req.response.close();
      return;
    }
    if (!WebSocketTransformer.isUpgradeRequest(req)) {
      req.response.statusCode = 400;
      await req.response.close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(req);
    final conn = Connection(socket, user);
    _sockets.add(conn);
    manager.onConnect(conn);

    socket.listen(
      (data) {
        if (data is! String || data.length > maxMessageBytes) {
          manager.strike(conn, 5, 'OVERSIZE');
          return;
        }
        if (!conn.limiter.allow()) {
          manager.strike(conn, 0.5, 'RATE_LIMITED');
          conn.send({'type': 'ERROR', 'code': 'RATE_LIMITED'});
          return;
        }
        Object? decoded;
        try {
          decoded = jsonDecode(data);
        } catch (_) {
          manager.strike(conn, 1, 'BAD_JSON');
          return;
        }
        if (decoded is! Map || decoded['type'] is! String) {
          manager.strike(conn, 1, 'BAD_MESSAGE');
          return;
        }
        unawaited(manager.handle(conn, decoded.cast<String, Object?>()));
      },
      onDone: () {
        conn.closed = true;
        _sockets.remove(conn);
        manager.onDisconnect(conn);
      },
      onError: (_) {
        conn.closed = true;
        _sockets.remove(conn);
        manager.onDisconnect(conn);
      },
      cancelOnError: true,
    );
  }
}
