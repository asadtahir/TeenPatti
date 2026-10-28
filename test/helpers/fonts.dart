import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the real Roboto weights that ship with the Flutter SDK so widget tests measure and
/// render text like a device does (the default test font, Ahem, has different line metrics).
/// Does nothing when the SDK font directory cannot be found.
Future<void> loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;
  final files = {
    for (final f in dir.listSync().whereType<File>()) f.uri.pathSegments.last.toLowerCase(): f,
  };

  Future<void> load(String family, List<String> names) async {
    final loader = FontLoader(family);
    for (final n in names) {
      final f = files[n];
      if (f != null) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }

  await load('Roboto', ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-black.ttf']);
  await load('MaterialIcons', ['materialicons-regular.otf']);
}
