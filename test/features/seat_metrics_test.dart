import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teen_patti/features/game/presentation/seat_view.dart';
import 'package:teen_patti/features/game/presentation/table_layout.dart';
import 'package:teen_patti_engine/teen_patti_engine.dart';

import '../helpers/fonts.dart';

void main() {
  setUpAll(loadRealFonts);

  // TableLayout reserves SeatMetrics for every seat; the real widget must never be bigger,
  // otherwise cards or labels would spill over neighbours or off the screen.
  for (final local in [false, true]) {
    for (final turn in [false, true]) {
      for (final winner in [false, true]) {
        testWidgets('seat fits its reserved box (local=$local turn=$turn winner=$winner)', (tester) async {
          final hand = [
            const PlayingCard(Rank.ace, Suit.spades),
            const PlayingCard(Rank.king, Suit.spades),
            const PlayingCard(Rank.queen, Suit.hearts),
          ];
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(fontFamily: 'Roboto'),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SeatView(
                  player: PlayerState(
                      id: 'p', name: 'A very long player name indeed', chips: 123456789, hand: hand, seen: true),
                  isLocal: local,
                  isTurn: turn,
                  isDealer: true,
                  isWinner: winner,
                  avatarSize: SeatMetrics.avatar,
                  cardWidth: local ? SeatMetrics.localCard : SeatMetrics.otherCard,
                  visibleCards: 3,
                  flipDuration: Duration.zero,
                  turnRemaining: turn ? const Duration(seconds: 9) : null,
                  turnTotal: turn ? const Duration(seconds: 15) : null,
                ),
              ),
            ),
          ));
          await tester.pump(const Duration(milliseconds: 600));
          final box = local ? SeatMetrics.local : SeatMetrics.other;
          final size = tester.getSize(find.byType(SeatView));
          expect(size.width, lessThanOrEqualTo(box.width), reason: 'width $size vs $box');
          expect(size.height, lessThanOrEqualTo(box.height), reason: 'height $size vs $box');
        });
      }
    }
  }
}
