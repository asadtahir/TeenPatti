import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/storage/key_value_store.dart';

const profileStorageKey = 'profile.v1';

class PlayerProfile {
  const PlayerProfile({
    this.username = 'Player',
    this.avatarIndex = 0,
    this.chips = AppConstants.startingChips,
  });

  final String username;
  final int avatarIndex;
  final int chips;

  PlayerProfile copyWith({String? username, int? avatarIndex, int? chips}) =>
      PlayerProfile(
        username: username ?? this.username,
        avatarIndex: avatarIndex ?? this.avatarIndex,
        chips: chips ?? this.chips,
      );

  String encode() => jsonEncode(
      {'username': username, 'avatarIndex': avatarIndex, 'chips': chips});

  static PlayerProfile decode(String? raw) {
    if (raw == null) return const PlayerProfile();
    try {
      final j = (jsonDecode(raw) as Map).cast<String, Object?>();
      const d = PlayerProfile();
      return PlayerProfile(
        username: j['username'] as String? ?? d.username,
        avatarIndex: j['avatarIndex'] as int? ?? d.avatarIndex,
        chips: j['chips'] as int? ?? d.chips,
      );
    } catch (_) {
      return const PlayerProfile();
    }
  }
}

class ProfileController extends Notifier<PlayerProfile> {
  @override
  PlayerProfile build() =>
      PlayerProfile.decode(ref.read(keyValueStoreProvider).getString(profileStorageKey));

  Future<void> update(PlayerProfile Function(PlayerProfile) change) async {
    state = change(state);
    await ref.read(keyValueStoreProvider).setString(profileStorageKey, state.encode());
  }
}

final profileProvider =
    NotifierProvider<ProfileController, PlayerProfile>(ProfileController.new);
