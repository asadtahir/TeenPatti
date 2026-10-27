import 'dart:convert';
import 'dart:io';

import 'rate_limiter.dart';
import 'store.dart';

/// One authenticated WebSocket.
class Connection {
  Connection(this.socket, this.user);

  final WebSocket socket;
  final UserRecord user;
  final limiter = RateLimiter();

  /// Anti-cheat score: malformed / abusive traffic adds to it.
  double strikes = 0;
  bool closed = false;

  void send(Map<String, Object?> message) {
    if (closed || socket.readyState != WebSocket.open) return;
    socket.add(jsonEncode(message));
  }

  Future<void> close([int code = WebSocketStatus.normalClosure, String reason = '']) async {
    if (closed) return;
    closed = true;
    try {
      await socket.close(code, reason);
    } catch (_) {}
  }
}
