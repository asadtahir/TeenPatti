import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/storage/key_value_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The table is laid out for tall screens; phones stay in portrait, tablets and desktops rotate freely.
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  if (view.physicalSize.shortestSide / view.devicePixelRatio < 600) {
    await SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [keyValueStoreProvider.overrideWithValue(SharedPrefsStore(prefs))],
    child: const TeenPattiApp(),
  ));
}
