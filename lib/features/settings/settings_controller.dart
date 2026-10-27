import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/key_value_store.dart';
import 'settings_model.dart';

const settingsStorageKey = 'settings.v1';

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() =>
      AppSettings.decode(ref.read(keyValueStoreProvider).getString(settingsStorageKey));

  Future<void> update(AppSettings Function(AppSettings) change) async {
    state = change(state);
    await ref.read(keyValueStoreProvider).setString(settingsStorageKey, state.encode());
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
