import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../errors/app_failure.dart';
import '../storage/key_value_store.dart';
import 'connection_status.dart';

const authTokenKey = 'auth.token.v1';
const authUserKey = 'auth.user.v1';

typedef Json = Map<String, Object?>;

/// Authenticated WebSocket with automatic reconnection and request/response helpers.
///
/// Reconnects with exponential backoff; if the server is reachable but rejects the
/// token (e.g. it restarted), the session registers a fresh guest and announces
/// `SESSION_RESET` so the UI can leave stale rooms.
class OnlineSession {
  OnlineSession({
    required this.baseUrl,
    required this.store,
    required this.displayName,
    this.backoffBase = const Duration(milliseconds: 500),
    this.backoffMax = const Duration(seconds: 10),
    this.requestTimeout = const Duration(seconds: 8),
  });

  final String baseUrl;
  final KeyValueStore store;
  final String displayName;
  final Duration backoffBase;
  final Duration backoffMax;
  final Duration requestTimeout;

  final _messages = StreamController<Json>.broadcast();
  final _status = StreamController<ConnectionStatus>.broadcast();
  final _pending = <String, Completer<Json>>{};

  WebSocketChannel? _channel;
  Completer<void>? _hello;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  ConnectionStatus _current = ConnectionStatus.offline;
  bool _closing = false;
  int _attempt = 0;
  int _failures = 0;
  int _reqSeq = 0;
  String? _token;

  String? userId;

  Stream<Json> get messages => _messages.stream;
  Stream<ConnectionStatus> get status => _status.stream;
  ConnectionStatus get currentStatus => _current;
  bool get isConnected => _current == ConnectionStatus.connected;

  void _setStatus(ConnectionStatus s) {
    if (_current == s) return;
    _current = s;
    if (!_status.isClosed) _status.add(s);
  }

  /// Registers (once) and opens the socket. Throws a friendly [AppFailure] on failure.
  Future<void> connect() async {
    _closing = false;
    _setStatus(ConnectionStatus.connecting);
    try {
      await _open();
    } catch (e) {
      _setStatus(ConnectionStatus.offline);
      throw e is AppFailure ? e : AppFailure(FailureKind.noInternet, cause: e);
    }
  }

  Future<void> _ensureToken() async {
    final saved = store.getString(authTokenKey);
    _token ??= (saved == null || saved.isEmpty) ? null : saved;
    if (_token != null) return;
    final res = await http
        .post(Uri.parse('$baseUrl/auth/guest'),
            headers: {'content-type': 'application/json'}, body: jsonEncode({'name': displayName}))
        .timeout(requestTimeout);
    if (res.statusCode == 429) throw const AppFailure(FailureKind.slowConnection);
    if (res.statusCode == 503) throw const AppFailure(FailureKind.maintenance);
    if (res.statusCode != 200) throw const AppFailure(FailureKind.serverError);
    final body = jsonDecode(res.body) as Json;
    _token = body['token'] as String;
    userId = body['userId'] as String;
    await store.setString(authTokenKey, _token!);
    await store.setString(authUserKey, userId!);
  }

  Uri _wsUri() {
    final base = Uri.parse(baseUrl);
    return Uri(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/ws',
      queryParameters: {'token': _token!},
    );
  }

  Future<void> _open() async {
    await _ensureToken();
    final channel = WebSocketChannel.connect(_wsUri());
    await channel.ready.timeout(requestTimeout);
    _channel = channel;
    _hello = Completer<void>();
    _sub = channel.stream.listen(
      _onData,
      onDone: _onDropped,
      onError: (_) => _onDropped(),
      cancelOnError: true,
    );
    // Connected means the server accepted our token and greeted us.
    await _hello!.future.timeout(requestTimeout);
  }

  void _onData(dynamic data) {
    if (data is! String) return;
    final Json msg;
    try {
      msg = (jsonDecode(data) as Map).cast<String, Object?>();
    } catch (_) {
      return;
    }
    switch (msg['type']) {
      case 'HELLO':
        userId = msg['userId'] as String?;
        _attempt = 0;
        _failures = 0;
        _setStatus(ConnectionStatus.connected);
        if (_hello != null && !_hello!.isCompleted) _hello!.complete();
      case 'RESULT':
        final c = _pending.remove(msg['id']);
        c?.complete(msg);
    }
    if (!_messages.isClosed) _messages.add(msg);
  }

  void _onDropped() {
    _sub?.cancel();
    _sub = null;
    _channel = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(const AppFailure(FailureKind.connectionLost));
    }
    _pending.clear();
    if (_closing) return;
    _setStatus(ConnectionStatus.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _retry?.cancel();
    final factor = 1 << (_attempt > 5 ? 5 : _attempt);
    var delay = backoffBase * factor;
    if (delay > backoffMax) delay = backoffMax;
    _attempt++;
    _retry = Timer(delay, () async {
      if (_closing) return;
      try {
        await _open();
      } catch (_) {
        _failures++;
        if (_failures >= 3 && await _serverReachable()) {
          // Server is up but refuses our token: start a fresh identity.
          _token = null;
          await store.setString(authTokenKey, '');
          _failures = 0;
          if (!_messages.isClosed) _messages.add({'type': 'SESSION_RESET'});
        }
        if (!_closing) _scheduleReconnect();
      }
    });
  }

  Future<bool> _serverReachable() async {
    try {
      final r = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 3));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fire-and-forget. Returns false when the socket is not open.
  bool send(Json message) {
    final ch = _channel;
    if (ch == null || !isConnected) return false;
    ch.sink.add(jsonEncode(message));
    return true;
  }

  /// Sends a command and waits for its RESULT.
  Future<Json> request(Json message) async {
    final id = 'q${_reqSeq++}';
    final completer = Completer<Json>();
    _pending[id] = completer;
    if (!send({...message, 'id': id})) {
      _pending.remove(id);
      throw const AppFailure(FailureKind.connectionLost);
    }
    try {
      return await completer.future.timeout(requestTimeout);
    } on TimeoutException {
      _pending.remove(id);
      throw const AppFailure(FailureKind.timeout);
    }
  }

  Future<void> close() async {
    _closing = true;
    _retry?.cancel();
    await _sub?.cancel();
    final ch = _channel;
    _channel = null;
    _setStatus(ConnectionStatus.offline);
    try {
      await ch?.sink.close();
    } catch (_) {}
    await _messages.close();
    await _status.close();
  }
}
