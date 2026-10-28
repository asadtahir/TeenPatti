import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teen_patti/app/app.dart';
import 'package:teen_patti/core/storage/key_value_store.dart';
import 'package:teen_patti/features/game/data/game_repository.dart';
import 'package:teen_patti/features/game/data/offline_game_repository.dart';
import 'package:teen_patti/features/game/presentation/table_layout.dart';
import 'package:teen_patti/features/profile/profile.dart';
import 'package:teen_patti/features/stats/stats.dart';
import 'package:teen_patti/shared/animations/ambient.dart';
import 'package:teen_patti_engine/teen_patti_engine.dart';

void main() {
  group('TableLayout', () {
    // Table areas (below the header, above the action bar) for common devices.
    const sizes = [
      Size(320, 460), Size(360, 480), Size(360, 560), Size(412, 700),
      Size(768, 800), Size(1000, 556), Size(1280, 640), Size(1920, 900),
    ];
    for (final size in sizes) {
      for (var n = 2; n <= 6; n++) {
        test('$n seats fit inside $size without clipping or overlap', () {
          final l = TableLayout(size);
          final screen = Offset.zero & size;
          final rects = [for (var i = 0; i < n; i++) l.seatRect(i, 0, n)];
          for (var i = 0; i < n; i++) {
            expect(screen.contains(rects[i].topLeft), isTrue, reason: 'seat $i top-left ${rects[i]}');
            expect(screen.contains(rects[i].bottomRight), isTrue, reason: 'seat $i bottom-right ${rects[i]}');
          }
          // The local seat is the lowest one.
          for (var i = 1; i < n; i++) {
            expect(rects[0].center.dy, greaterThanOrEqualTo(rects[i].center.dy));
          }
          final pot = l.potRect;
          final deck = l.deckRect;
          final all = [...rects, pot, deck];
          for (var i = 0; i < all.length; i++) {
            for (var j = i + 1; j < all.length; j++) {
              expect(all[i].overlaps(all[j]), isFalse, reason: 'rect $i ${all[i]} overlaps $j ${all[j]}');
            }
          }
        });
      }
    }

    test('seats do not coincide', () {
      final l = TableLayout(const Size(400, 600));
      final pts = {for (var i = 0; i < 6; i++) l.seatCenter(i, 0, 6)};
      expect(pts.length, 6);
    });
  });

  group('OfflineGameRepository', () {
    test('plays a full hand: auto-folds the idle human, conserves chips', () async {
      final repo = OfflineGameRepository(
        playerName: 'Tester',
        playerChips: 10000,
        botCount: 3,
        difficulty: Difficulty.medium,
        settings: const GameSettings(turnSeconds: 1),
        random: SeededRandomSource(5),
        botThinkTime: const Duration(milliseconds: 5),
      );
      final updates = <GameUpdate>[];
      final done = Completer<void>();
      repo.updates.listen((u) {
        updates.add(u);
        if (u.state.isFinished && !done.isCompleted) done.complete();
      });
      await repo.startGame();
      await done.future.timeout(const Duration(seconds: 30));

      final first = updates.first;
      expect(first.events.map((e) => e.type), contains(GameEvent.cardsDealt));
      // Bot hands are never sent to the UI mid-game.
      for (final u in updates.where((u) => !u.state.isFinished)) {
        for (final p in u.state.players.where((p) => p.id != 'you')) {
          expect(p.hand, isEmpty);
        }
      }
      final last = updates.last.state;
      expect(last.players.fold<int>(0, (a, p) => a + p.chips), 10000 * 4);
      await repo.dispose();
    });

    test('rejects actions for other seats and out-of-turn moves', () async {
      final repo = OfflineGameRepository(
        playerName: 'T',
        playerChips: 10000,
        botCount: 2,
        difficulty: Difficulty.easy,
        random: SeededRandomSource(1),
        botThinkTime: const Duration(minutes: 5),
      );
      await repo.startGame();
      expect(() => repo.send(const Call('bot1')), throwsA(isA<InvalidActionException>()));
      await repo.dispose();
    });

    test('broke players are topped up for the next hand', () async {
      final repo = OfflineGameRepository(
        playerName: 'T',
        playerChips: 10, // below the boot
        botCount: 2,
        difficulty: Difficulty.easy,
        random: SeededRandomSource(1),
        botThinkTime: const Duration(minutes: 5),
      );
      final first = repo.updates.first;
      await repo.startGame();
      final s = (await first).state;
      expect(s.playerById('you').chips + s.playerById('you').invested, 10000);
      await repo.dispose();
    });
  });

  testWidgets('offline game: deal, play, show result, update profile and stats', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final store = MemoryStore();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        ambientMotionProvider.overrideWithValue(false),
      ],
      child: const TeenPattiApp(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('OFFLINE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START GAME'));
    // Page transition + deal animation.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('PACK'), findsOneWidget);
    expect(find.textContaining('POT'), findsWidgets);
    expect(find.text('You'), findsOneWidget);

    // Play: fold as soon as it is our turn, then let the bots finish.
    await tester.tap(find.text('PACK'));
    for (var i = 0; i < 200 && find.text('NEXT HAND').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('NEXT HAND'), findsOneWidget);

    final profile = PlayerProfile.decode(store.getString(profileStorageKey));
    expect(profile.chips, lessThan(10000)); // we folded after paying the boot at least
    expect(store.getString(statsStorageKey), isNotNull);

    await tester.tap(find.text('LEAVE TABLE'));
    await tester.pumpAndSettle();
    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
    expect(find.text('PLAY'), findsOneWidget, reason: 'visible texts: $texts');
  });
}
