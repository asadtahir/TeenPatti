import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/key_value_store.dart';

const statsStorageKey = 'stats.v1';
const _maxHistory = 50;

class GameRecord {
  const GameRecord({
    required this.at,
    required this.won,
    required this.pot,
    required this.net,
    required this.players,
    this.handName,
  });

  final DateTime at;
  final bool won;
  final int pot;

  /// Chips gained (positive) or lost (negative) this game.
  final int net;
  final int players;
  final String? handName;

  Map<String, Object?> toJson() => {
        'at': at.millisecondsSinceEpoch,
        'won': won,
        'pot': pot,
        'net': net,
        'players': players,
        'handName': handName,
      };

  factory GameRecord.fromJson(Map<String, Object?> j) => GameRecord(
        at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
        won: j['won'] as bool,
        pot: j['pot'] as int,
        net: j['net'] as int,
        players: j['players'] as int,
        handName: j['handName'] as String?,
      );
}

class Stats {
  const Stats(this.history);
  final List<GameRecord> history;

  int get played => history.length;
  int get wins => history.where((g) => g.won).length;
  int get biggestPot => history.fold(0, (m, g) => g.pot > m ? g.pot : m);
}

/// Offline statistics and game history, persisted locally.
class StatsController extends Notifier<Stats> {
  @override
  Stats build() {
    final raw = ref.read(keyValueStoreProvider).getString(statsStorageKey);
    if (raw == null) return const Stats([]);
    try {
      return Stats([
        for (final e in jsonDecode(raw) as List)
          GameRecord.fromJson((e as Map).cast<String, Object?>())
      ]);
    } catch (_) {
      return const Stats([]);
    }
  }

  Future<void> record(GameRecord r) async {
    final list = [r, ...state.history].take(_maxHistory).toList();
    state = Stats(list);
    await ref
        .read(keyValueStoreProvider)
        .setString(statsStorageKey, jsonEncode([for (final g in list) g.toJson()]));
  }
}

final statsProvider = NotifierProvider<StatsController, Stats>(StatsController.new);
