import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teen_patti/core/errors/app_failure.dart';
import 'package:teen_patti/core/errors/error_mapper.dart';
import 'package:teen_patti/shared/widgets/chip_badge.dart';
import 'package:teen_patti_engine/teen_patti_engine.dart';

void main() {
  test('formatChips groups thousands', () {
    expect(formatChips(0), '0');
    expect(formatChips(999), '999');
    expect(formatChips(10000), '10,000');
    expect(formatChips(1234567), '1,234,567');
  });

  test('mapError hides technical details', () {
    expect(mapError(TimeoutException('x')).kind, FailureKind.timeout);
    expect(mapError(const SocketException('boom')).kind, FailureKind.noInternet);
    final f = mapError(WebSocketException('Connection reset by peer'));
    expect(f.kind, FailureKind.connectionLost);
    expect(f.message, isNot(contains('WebSocketException')));
    expect(mapError(StateError('x')).kind, FailureKind.unknown);
  });

  test('PlayingCard equality', () {
    expect(const PlayingCard(Rank.ace, Suit.spades),
        const PlayingCard(Rank.ace, Suit.spades));
    expect(const PlayingCard(Rank.ace, Suit.spades),
        isNot(const PlayingCard(Rank.ace, Suit.hearts)));
  });
}
