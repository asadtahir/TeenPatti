import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/network/connection_status.dart';
import '../../core/network/online_session.dart';
import '../../core/storage/key_value_store.dart';
import '../game/data/online_game_repository.dart';
import '../profile/profile.dart';

const serverUrlKey = 'server.url.v1';
const defaultServerUrl = 'http://127.0.0.1:8080';

class ServerUrlController extends Notifier<String> {
  @override
  String build() => ref.read(keyValueStoreProvider).getString(serverUrlKey) ?? defaultServerUrl;

  Future<void> set(String url) async {
    state = url.trim().replaceAll(RegExp(r'/+$'), '');
    await ref.read(keyValueStoreProvider).setString(serverUrlKey, state);
  }
}

/// Reconnect backoff base; overridden in tests to keep them fast.
final onlineBackoffProvider = Provider<Duration>((ref) => const Duration(milliseconds: 500));

final serverUrlProvider =NotifierProvider<ServerUrlController, String>(ServerUrlController.new);

class RoomPlayer {
  const RoomPlayer({required this.id, required this.name, required this.chips, required this.connected, required this.host});
  final String id;
  final String name;
  final int chips;
  final bool connected;
  final bool host;
}

class RoomInfo {
  const RoomInfo({
    required this.code,
    required this.hostId,
    required this.maxPlayers,
    required this.boot,
    required this.playing,
    required this.players,
  });

  final String code;
  final String hostId;
  final int maxPlayers;
  final int boot;
  final bool playing;
  final List<RoomPlayer> players;

  factory RoomInfo.fromJson(Json j) => RoomInfo(
        code: j['code'] as String,
        hostId: j['hostId'] as String,
        maxPlayers: j['maxPlayers'] as int,
        boot: j['boot'] as int,
        playing: j['status'] == 'playing',
        players: [
          for (final p in (j['players'] as List))
            RoomPlayer(
              id: (p as Map)['id'] as String,
              name: p['name'] as String,
              chips: p['chips'] as int,
              connected: p['connected'] as bool,
              host: p['host'] as bool,
            ),
        ],
      );
}

class OnlineState {
  const OnlineState({
    this.connection = ConnectionStatus.offline,
    this.room,
    this.userId,
    this.failure,
    this.busy = false,
  });

  final ConnectionStatus connection;
  final RoomInfo? room;
  final String? userId;
  final AppFailure? failure;
  final bool busy;

  bool get isHost => room != null && room!.hostId == userId;

  OnlineState copyWith({
    ConnectionStatus? connection,
    Object? room = _keep,
    String? userId,
    Object? failure = _keep,
    bool? busy,
  }) =>
      OnlineState(
        connection: connection ?? this.connection,
        room: identical(room, _keep) ? this.room : room as RoomInfo?,
        userId: userId ?? this.userId,
        failure: identical(failure, _keep) ? this.failure : failure as AppFailure?,
        busy: busy ?? this.busy,
      );
}

const Object _keep = Object();

/// Owns the online session, the room the player is in, and the repository the table uses.
class OnlineController extends Notifier<OnlineState> {
  OnlineSession? _session;
  OnlineGameRepository? _repo;
  StreamSubscription<Json>? _msgSub;
  StreamSubscription<ConnectionStatus>? _statusSub;

  /// The repository to hand to the game controller once the hand starts.
  OnlineGameRepository? get repository => _repo;

  @override
  OnlineState build() {
    ref.onDispose(_close);
    return const OnlineState();
  }

  Future<bool> _ensureConnected() async {
    if (_session != null && _session!.isConnected) return true;
    await _close();
    final session = OnlineSession(
      baseUrl: ref.read(serverUrlProvider),
      store: ref.read(keyValueStoreProvider),
      displayName: ref.read(profileProvider).username,
      backoffBase: ref.read(onlineBackoffProvider),
    );
    try {
      state = state.copyWith(connection: ConnectionStatus.connecting, failure: null);
      await session.connect();
    } catch (e) {
      state = state.copyWith(connection: ConnectionStatus.offline, failure: mapError(e));
      return false;
    }
    _session = session;
    _repo = OnlineGameRepository(session);
    _msgSub = session.messages.listen(_onMessage);
    _statusSub = session.status.listen((s) => state = state.copyWith(connection: s));
    state = state.copyWith(connection: session.currentStatus, userId: session.userId);
    return true;
  }

  void _onMessage(Json m) {
    switch (m['type']) {
      case 'HELLO':
        state = state.copyWith(userId: m['userId'] as String?);
      case 'ROOM_STATE':
        state = state.copyWith(room: RoomInfo.fromJson(m));
      case 'ROOM_LEFT':
        state = state.copyWith(room: null);
      case 'SESSION_RESET':
        state = state.copyWith(room: null, failure: const AppFailure(FailureKind.connectionLost));
      case 'ERROR':
        if (m['code'] == 'GAME_ABORTED') state = state.copyWith(failure: const AppFailure(FailureKind.serverError));
    }
  }

  Future<String?> _command(Json msg) async {
    if (!await _ensureConnected()) return null;
    state = state.copyWith(busy: true, failure: null);
    try {
      final r = await _session!.request(msg);
      if (r['ok'] != true) {
        state = state.copyWith(busy: false, failure: AppFailure(FailureKind.invalidAction, cause: r['error']));
        return null;
      }
      state = state.copyWith(busy: false);
      return (r['roomCode'] as String?) ?? '';
    } catch (e) {
      state = state.copyWith(busy: false, failure: mapError(e));
      return null;
    }
  }

  /// Returns the room code, or null on failure ([OnlineState.failure] explains why).
  Future<String?> createRoom({required int maxPlayers, int boot = 100}) =>
      _command({'type': 'CREATE_ROOM', 'maxPlayers': maxPlayers, 'boot': boot});

  Future<String?> joinRoom(String code) => _command({'type': 'JOIN_ROOM', 'code': code.trim().toUpperCase()});

  Future<String?> quickPlay(int players) => _command({'type': 'QUICK_PLAY', 'players': players});

  Future<bool> startGame() async => await _command({'type': 'START_GAME'}) != null;

  Future<void> leaveRoom() async {
    final s = _session;
    if (s != null && s.isConnected && state.room != null) {
      try {
        await s.request({'type': 'LEAVE_ROOM'});
      } catch (_) {}
    }
    state = state.copyWith(room: null);
  }

  void clearFailure() => state = state.copyWith(failure: null);

  Future<void> _close() async {
    await _msgSub?.cancel();
    await _statusSub?.cancel();
    _msgSub = null;
    _statusSub = null;
    await _repo?.dispose();
    _repo = null;
    await _session?.close();
    _session = null;
  }

  Future<void> disconnect() async {
    await _close();
    state = const OnlineState();
  }
}

final onlineProvider = NotifierProvider<OnlineController, OnlineState>(OnlineController.new);

/// Maps server error codes to text a player can read.
String onlineErrorText(AppFailure f) {
  final cause = f.cause;
  if (f.kind == FailureKind.invalidAction && cause is String) {
    return switch (cause) {
      'ROOM_NOT_FOUND' => 'No room with that code.',
      'ROOM_FULL' => 'That room is full.',
      'GAME_IN_PROGRESS' => 'A hand is already in progress. Try again in a moment.',
      'ALREADY_IN_ROOM' => 'You are already in a room.',
      'NOT_HOST' => 'Only the host can start the game.',
      'NOT_ENOUGH_PLAYERS' => 'Need at least 2 players with enough chips.',
      'INSUFFICIENT_CHIPS' => 'You do not have enough chips for this table.',
      'BAD_CODE' => 'Enter a valid room code.',
      _ => 'That is not allowed right now.',
    };
  }
  return f.message;
}
