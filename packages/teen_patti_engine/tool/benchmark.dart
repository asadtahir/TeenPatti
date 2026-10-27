import 'dart:io';
import 'package:teen_patti_engine/teen_patti_engine.dart';

/// Run: dart run tool/benchmark.dart

void main() {
  const settings = GameSettings(bootAmount: 100, maxStakeMultiple: 16, potLimitMultiple: 200);
  final sw = Stopwatch()..start();
  HandStrengthAnalyzer.strength(const [
    PlayingCard(Rank.ace, Suit.clubs), PlayingCard(Rank.king, Suit.clubs), PlayingCard(Rank.two, Suit.hearts)
  ]);
  stdout.writeln('strength table build: ${sw.elapsedMilliseconds} ms');

  sw.reset();
  var actions = 0;
  const games = 5000;
  for (var seed = 0; seed < games; seed++) {
    final rng = SeededRandomSource(seed);
    final n = 3 + seed % 4;
    final ids = [for (var i = 0; i < n; i++) 'b$i'];
    final ai = AIEngine.forBots(ids, Difficulty.hard, rng);
    var s = TeenPattiEngine.startGame(
      players: [for (final id in ids) PlayerState(id: id, name: id, chips: 20000)],
      settings: settings,
      random: rng,
    ).state;
    while (!s.isFinished) {
      final p = s.pendingSideShow;
      final a = p != null ? ai.sideShowReply(s, p.responderId) : ai.nextAction(s, s.currentPlayer.id);
      final r = TeenPattiEngine.apply(s, a);
      ai.observe(r.events);
      s = r.state;
      actions++;
    }
  }
  stdout.writeln('$games full hard-AI games, $actions actions: ${sw.elapsedMilliseconds} ms '
      '(${(sw.elapsedMicroseconds / actions).toStringAsFixed(1)} µs/action)');
}
