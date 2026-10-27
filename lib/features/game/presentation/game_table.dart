import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teen_patti_engine/teen_patti_engine.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../shared/animations/animated_counter.dart';
import '../../../shared/animations/animation_profile.dart';
import '../../../shared/animations/confetti_burst.dart';
import '../../../shared/animations/effects.dart';
import '../../../shared/widgets/card_views.dart';
import '../../../shared/widgets/chip_badge.dart';
import '../../../shared/widgets/chip_disc.dart';
import '../../online/online_controller.dart';
import 'feedback_service.dart';
import 'game_controller.dart';
import 'result_overlay.dart';
import 'seat_view.dart';
import 'table_layout.dart';

/// The felt table: seats, pot, deck and every animation layered on top.
class GameTable extends ConsumerStatefulWidget {
  const GameTable({super.key});

  @override
  ConsumerState<GameTable> createState() => _GameTableState();
}

class _GameTableState extends ConsumerState<GameTable> {
  final _effects = EffectsController();
  final _rng = math.Random();
  TableLayout? _layout;

  /// Cards that have landed per player during the deal; null when not dealing.
  Map<String, int>? _dealt;
  bool _showResult = false;
  bool _celebrate = false;
  Timer? _resultTimer;
  int _celebrateSeed = 1;

  @override
  void initState() {
    super.initState();
    // Catch an update that arrived before this widget started listening.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handle(ref.read(gameControllerProvider));
    });
  }

  @override
  void dispose() {
    _resultTimer?.cancel();
    _effects.dispose();
    super.dispose();
  }

  AnimationProfile get _profile => ref.read(animationProfileProvider);

  Offset? _seat(GameState g, String id) {
    final layout = _layout;
    if (layout == null) return null;
    final ui = ref.read(gameControllerProvider);
    final local = g.indexOf(ui.localPlayerId);
    final i = g.indexOf(id);
    if (i < 0 || local < 0) return null;
    return layout.seatCenter(i, local, g.players.length);
  }

  void _handle(GameUiState ui) {
    final g = ui.game;
    final layout = _layout;
    if (g == null || layout == null) return;
    final p = _profile;

    for (final e in ui.events) {
      switch (e.type) {
        case GameEvent.cardsDealt:
          _startDeal(g, (e.data['order'] as List).cast<String>());
        case GameEvent.playerBet:
          final from = _seat(g, e.playerId!);
          if (from == null) break;
          final kind = e.data['kind'] as String;
          final blind = e.data['blind'] == true;
          final label = switch (kind) {
            'RAISE' => 'RAISE ${e.amount}',
            'SHOW' => 'SHOW ${e.amount}',
            'SIDE_SHOW' => 'SIDE SHOW ${e.amount}',
            _ => blind ? 'BLIND ${e.amount}' : 'CALL ${e.amount}',
          };
          _effects.add(FloatingTextEffect(
            at: from + const Offset(0, -20),
            text: label,
            color: kind == 'RAISE' ? AppColors.warning : AppColors.gold,
          ));
          _effects.add(ChipFlightEffect(
            from: from,
            to: layout.potCenter,
            count: kind == 'RAISE' ? 5 : 3,
            duration: p.d(const Duration(milliseconds: 520)),
          ));
        case GameEvent.playerFolded:
          final at = _seat(g, e.playerId!);
          if (at != null) {
            _effects.add(FloatingTextEffect(at: at + const Offset(0, -20), text: 'PACK', color: AppColors.textMuted));
          }
        case GameEvent.playerSeen:
          final at = _seat(g, e.playerId!);
          if (at != null && e.playerId != ui.localPlayerId) {
            _effects.add(FloatingTextEffect(
                at: at + const Offset(0, -20), text: 'SEEN', color: AppColors.success));
          }
        case GameEvent.gameEnded:
          _onGameEnded(g, e);
      }
    }
  }

  void _startDeal(GameState g, List<String> order) {
    final layout = _layout!;
    final p = _profile;
    _resultTimer?.cancel();
    setState(() {
      _showResult = false;
      _celebrate = false;
      _dealt = {for (final pl in g.players) pl.id: 0};
    });
    final stagger = p.d(AppDurations.dealStagger);
    for (var j = 0; j < order.length; j++) {
      final id = order[j];
      final to = _seat(g, id);
      if (to == null) continue;
      final isLast = j == order.length - 1;
      _effects.add(FlyingCardEffect(
        from: layout.deckCenter,
        to: to,
        cardWidth: layout.otherCardWidth,
        spin: (_rng.nextDouble() - 0.5) * 0.8,
        delay: stagger * j,
        duration: p.d(AppDurations.cardDeal),
        onDone: () {
          if (!mounted) return;
          setState(() {
            final d = _dealt;
            if (d == null) return;
            d[id] = (d[id] ?? 0) + 1;
            if (isLast) _dealt = null;
          });
        },
      ));
    }
  }

  void _onGameEnded(GameState g, GameEvent e) {
    final layout = _layout!;
    final p = _profile;
    final ui = ref.read(gameControllerProvider);
    final winners = (e.data['winnerIds'] as List).cast<String>();
    final payouts = (e.data['payouts'] as Map).cast<String, int>();

    // Let showdown cards be seen before the pot moves.
    final lead = p.d(const Duration(milliseconds: 700));
    for (final w in winners) {
      final to = _seat(g, w);
      if (to == null) continue;
      _effects.add(ChipFlightEffect(
        from: layout.potCenter,
        to: to,
        count: 8,
        chipSize: 24,
        delay: lead,
        duration: p.d(const Duration(milliseconds: 800)),
      ));
      _effects.add(FloatingTextEffect(
        at: to + const Offset(0, -30),
        text: '+${formatChips(payouts[w] ?? 0)}',
        color: AppColors.success,
        delay: lead,
      ));
    }
    final iWon = winners.contains(ui.localPlayerId);
    setState(() {
      _celebrate = iWon;
      _celebrateSeed = _rng.nextInt(1 << 20);
    });
    _resultTimer?.cancel();
    _resultTimer = Timer(p.d(const Duration(milliseconds: 1900)), () {
      if (mounted) setState(() => _showResult = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GameUiState>(gameControllerProvider, (prev, next) {
      if (prev?.batch != next.batch) _handle(next);
    });
    final ui = ref.watch(gameControllerProvider);
    final profile = ref.watch(animationProfileProvider);
    final g = ui.game;
    if (g == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }

    return LayoutBuilder(builder: (context, constraints) {
      final layout = TableLayout(constraints.biggest);
      _layout = layout;
      final local = g.indexOf(ui.localPlayerId);

      return Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(child: _Felt(layout: layout)),
        _deck(layout),
        _pot(layout, g),
        for (var i = 0; i < g.players.length; i++) _seatAt(g, ui, layout, i, local, profile),
        Positioned.fill(child: EffectsLayer(controller: _effects)),
        if (_celebrate && profile.particles > 0)
          Positioned.fill(child: ConfettiBurst(key: ValueKey(_celebrateSeed), count: profile.particles, seed: _celebrateSeed)),
        if (g.isFinished && _showResult)
          Positioned.fill(
            child: ResultOverlay(
              game: g,
              localId: ui.localPlayerId,
              // Online, only the host starts the next hand.
              onNext: ui.isOnline && !ref.watch(onlineProvider.select((s) => s.isHost))
                  ? null
                  : () => ref.read(gameControllerProvider.notifier).nextHand(),
            ),
          ),
      ]);
    });
  }

  Widget _deck(TableLayout layout) {
    final w = layout.otherCardWidth;
    return Positioned(
      left: layout.deckCenter.dx - w / 2,
      top: layout.deckCenter.dy - cardHeightFor(w) / 2,
      child: Stack(children: [
        for (var i = 3; i >= 0; i--)
          Transform.translate(offset: Offset(i * 1.2, -i * 1.2), child: CardBack(width: w)),
      ]),
    );
  }

  Widget _pot(TableLayout layout, GameState g) {
    return Positioned(
      left: layout.potCenter.dx - 70,
      top: layout.potCenter.dy - 44,
      width: 140,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ChipStack(amount: g.pot),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(AppRadius.pill)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('POT ', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
              AnimatedCounter(
                value: g.pot,
                duration: _profile.d(const Duration(milliseconds: 450)),
                style: const TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 2),
        Text('Stake ${formatChips(g.stake)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ]),
    );
  }

  Widget _seatAt(GameState g, GameUiState ui, TableLayout layout, int i, int local, AnimationProfile profile) {
    final p = g.players[i];
    final isLocal = p.id == ui.localPlayerId;
    final c = layout.seatCenter(i, local, g.players.length);
    final turn = !g.isFinished && g.pendingSideShow == null && g.currentIndex == i;
    final deadline = ui.deadline;
    final remaining = turn && deadline != null ? deadline.difference(DateTime.now()) : null;

    return Positioned(
      left: c.dx,
      top: c.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: SeatView(
          player: p,
          isLocal: isLocal,
          isTurn: turn,
          isDealer: i == g.dealerIndex,
          isWinner: g.isFinished && g.winnerIds.contains(p.id),
          avatarSize: layout.avatarSize,
          cardWidth: isLocal ? layout.myCardWidth : layout.otherCardWidth,
          visibleCards: _dealt?[p.id] ?? 3,
          flipDuration: profile.d(AppDurations.cardFlip),
          turnRemaining: remaining == null || remaining.isNegative ? null : remaining,
          turnTotal: Duration(seconds: g.settings.turnSeconds),
          onWarningTick: (_) => ref.read(feedbackServiceProvider).timerWarning(),
          glow: profile.glow,
        ),
      ),
    );
  }
}

class _Felt extends StatelessWidget {
  const _Felt({required this.layout});
  final TableLayout layout;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(painter: _FeltPainter(layout)),
    );
  }
}

class _FeltPainter extends CustomPainter {
  _FeltPainter(this.layout);
  final TableLayout layout;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
        center: layout.center, width: layout.radiusX * 2.1, height: layout.radiusY * 2.2);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(rect.shortestSide * 0.5));

    canvas.drawRRect(rrect.shift(const Offset(0, 10)), Paint()..color = Colors.black54..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    // Wood rail.
    canvas.drawRRect(
        rrect.inflate(12),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6B4423), Color(0xFF3A2312)],
          ).createShader(rect.inflate(12)));
    // Felt with a soft spotlight.
    canvas.drawRRect(
        rrect,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(0, -0.2),
            radius: 0.95,
            colors: [AppColors.feltLight, AppColors.felt, AppColors.feltDark],
            stops: [0, 0.55, 1],
          ).createShader(rect));
    canvas.drawRRect(
        rrect.deflate(14),
        Paint()
          ..color = AppColors.gold.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_FeltPainter old) => old.layout.size != layout.size;
}
