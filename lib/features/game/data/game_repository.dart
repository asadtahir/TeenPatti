import 'package:teen_patti_engine/teen_patti_engine.dart';

import '../../../core/network/connection_status.dart';

/// One state change pushed to the UI.
class GameUpdate {
  const GameUpdate({
    required this.state,
    this.events = const [],
    this.turnDeadline,
    this.connection = ConnectionStatus.connected,
  });

  /// Already redacted for the local player.
  final GameState state;
  final List<GameEvent> events;
  final DateTime? turnDeadline;
  final ConnectionStatus connection;
}

/// The only thing the presentation layer knows about a game session.
/// Implemented by an in-process engine (offline) and a WebSocket client (online).
abstract interface class GameRepository {
  String get localPlayerId;

  Stream<GameUpdate> get updates;

  /// Begin the first (or next) hand.
  Future<void> startGame();

  /// Throws [InvalidActionException] or a mapped failure when rejected.
  Future<void> send(GameAction action);

  Future<void> dispose();
}
