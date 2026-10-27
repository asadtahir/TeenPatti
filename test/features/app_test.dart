import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:teen_patti/app/app.dart';
import 'package:teen_patti/core/storage/key_value_store.dart';
import 'package:teen_patti/features/settings/settings_controller.dart';
import 'package:teen_patti/features/settings/settings_model.dart';

Widget _app(KeyValueStore store) => ProviderScope(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
      child: const TeenPattiApp(),
    );

void main() {
  test('settings persist and survive corrupt data', () async {
    final store = MemoryStore();
    final c1 = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)]);
    await c1.read(settingsProvider.notifier).update(
        (s) => s.copyWith(sound: false, graphicsQuality: GraphicsQuality.low));
    c1.dispose();

    final c2 = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)]);
    expect(c2.read(settingsProvider).sound, false);
    expect(c2.read(settingsProvider).graphicsQuality, GraphicsQuality.low);
    c2.dispose();

    expect(AppSettings.decode('{not json').sound, true);
  });

  testWidgets('home screen shows PLAY and navigates to offline setup',
      (tester) async {
    await tester.pumpWidget(_app(MemoryStore()));
    await tester.pumpAndSettle();
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('10,000'), findsOneWidget);

    await tester.tap(find.text('OFFLINE'));
    await tester.pumpAndSettle();
    expect(find.text('Offline Mode'), findsOneWidget);
    expect(find.text('START GAME'), findsOneWidget);
    expect(find.text('6 Players'), findsOneWidget);
  });

  testWidgets('settings toggle updates state', (tester) async {
    final store = MemoryStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sound'));
    await tester.pumpAndSettle();
    expect(AppSettings.decode(store.getString(settingsStorageKey)).sound, false);
  });

  testWidgets('lobby renders its sections and shows a friendly message when the server is unreachable', (tester) async {
    await tester.pumpWidget(_app(MemoryStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ONLINE'));
    await tester.pumpAndSettle();
    for (final section in ['Quick Play', 'Private Room', 'Friends', 'Recent Games']) {
      expect(find.text(section), findsOneWidget);
    }
    expect(find.text('3 Players'), findsOneWidget);
    expect(find.text('6 Players'), findsOneWidget);

    // Widget tests have no network: the failure must surface as plain language.
    await tester.runAsync(() async {
      await tester.tap(find.text('CREATE ROOM'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('room screen shows code, players and host controls', (tester) async {
    await tester.pumpWidget(_app(MemoryStore()));
    await tester.pumpAndSettle();
    final ctx = tester.element(find.text('PLAY'));
    GoRouter.of(ctx).go('/room/ABCD123');
    await tester.pumpAndSettle();
    expect(find.text('Room Code'), findsOneWidget);
    expect(find.text('ABCD123'), findsOneWidget);
    expect(find.text('LEAVE ROOM'), findsOneWidget);
  });
}
