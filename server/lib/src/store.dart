import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

const startingBalance = 10000;

class UserRecord {
  UserRecord({required this.id, required this.name, required this.balance});
  final String id;
  String name;
  int balance;
}

class ActionLogEntry {
  ActionLogEntry({
    required this.at,
    required this.userId,
    required this.roomCode,
    required this.actionId,
    required this.action,
    required this.accepted,
    this.error,
  });
  final DateTime at;
  final String userId;
  final String roomCode;
  final String actionId;
  final Map<String, Object?> action;
  final bool accepted;
  final String? error;
}

class TransactionEntry {
  TransactionEntry(this.at, this.userId, this.delta, this.reason, this.gameId);
  final DateTime at;
  final String userId;
  final int delta;
  final String reason;
  final String gameId;
}

class GameHistoryEntry {
  GameHistoryEntry({
    required this.id,
    required this.roomCode,
    required this.at,
    required this.playerIds,
    required this.winnerIds,
    required this.pot,
    required this.handName,
  });
  final String id;
  final String roomCode;
  final DateTime at;
  final List<String> playerIds;
  final List<String> winnerIds;
  final int pot;
  final String? handName;
}

/// Persistence boundary. `schema.sql` describes the PostgreSQL equivalent;
/// only the in-memory implementation exists today.
abstract interface class Store {
  Future<(UserRecord user, String token)> createUser(String name);
  Future<UserRecord?> userByToken(String token);
  Future<void> setBalance(String userId, int balance);
  Future<void> logAction(ActionLogEntry e);
  Future<void> addTransaction(TransactionEntry e);
  Future<void> saveGame(GameHistoryEntry g);
}

String hashToken(String token) => sha256.convert(utf8.encode(token)).toString();

String randomHex(int bytes) {
  final r = Random.secure();
  return [for (var i = 0; i < bytes; i++) r.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
}

/// Tokens are stored only as SHA-256 hashes.
class InMemoryStore implements Store {
  final Map<String, UserRecord> _byTokenHash = {};
  final actionLog = <ActionLogEntry>[];
  final transactions = <TransactionEntry>[];
  final games = <GameHistoryEntry>[];

  @override
  Future<(UserRecord, String)> createUser(String name) async {
    final token = randomHex(32);
    final user = UserRecord(id: randomHex(8), name: name, balance: startingBalance);
    _byTokenHash[hashToken(token)] = user;
    return (user, token);
  }

  @override
  Future<UserRecord?> userByToken(String token) async => _byTokenHash[hashToken(token)];

  @override
  Future<void> setBalance(String userId, int balance) async {
    for (final u in _byTokenHash.values) {
      if (u.id == userId) u.balance = balance;
    }
  }

  @override
  Future<void> logAction(ActionLogEntry e) async {
    actionLog.add(e);
    if (actionLog.length > 20000) actionLog.removeRange(0, 5000);
  }

  @override
  Future<void> addTransaction(TransactionEntry e) async => transactions.add(e);

  @override
  Future<void> saveGame(GameHistoryEntry g) async => games.add(g);
}
