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
import '../../../shared/animations/entrance.dart';
import '../../../shared/widgets/card_views.dart';
import '../../../shared/widgets/chip_badge.dart';
import '../../../shared/widgets/chip_disc.dart';
import '../../../shared/widgets/suit_shapes.dart';
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
          _effects.add(
            FloatingTextEffect(
              at: from + const Offset(0, -20),
              text: label,
              color: kind == 'RAISE' ? AppColors.warning : AppColors.gold,
            ),
          );
          _effects.add(
            ChipFlightEffect(
              from: from,
              to: layout.potCenter,
              count: kind == 'RAISE' ? 5 : 3,
              duration: p.d(const Duration(milliseconds: 520)),
            ),
          );
        case GameEvent.playerFolded:
          final at = _seat(g, e.playerId!);
          if (at != null) {
            _effects.add(
              FloatingTextEffect(
                at: at + const Offset(0, -20),
                text: 'PACK',
                color: AppColors.textMuted,
              ),
            );
          }
        case GameEvent.playerSeen:
          final at = _seat(g, e.playerId!);
          if (at != null && e.playerId != ui.localPlayerId) {
            _effects.add(
              FloatingTextEffect(
                at: at + const Offset(0, -20),
                text: 'SEEN',
                color: AppColors.success,
              ),
            );
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
      _effects.add(
        FlyingCardEffect(
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
        ),
      );
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
      _effects.add(
        ChipFlightEffect(
          from: layout.potCenter,
          to: to,
          count: 8,
          chipSize: 24,
          delay: lead,
          duration: p.d(const Duration(milliseconds: 800)),
        ),
      );
      _effects.add(
        FloatingTextEffect(
          at: to + const Offset(0, -30),
          text: '+${formatChips(payouts[w] ?? 0)}',
          color: AppColors.success,
          delay: lead,
        ),
      );
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
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = TableLayout(constraints.biggest);
        _layout = layout;
        final local = g.indexOf(ui.localPlayerId);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Entrance(
                offset: Offset.zero,
                scaleFrom: 0.88,
                duration: const Duration(milliseconds: 700),
                child: _Felt(layout: layout),
              ),
            ),
            _deck(layout),
            _pot(layout, g),
            for (var i = 0; i < g.players.length; i++)
              _seatAt(g, ui, layout, i, local, profile),
            Positioned.fill(child: EffectsLayer(controller: _effects)),
            if (_celebrate && profile.particles > 0)
              Positioned.fill(
                child: ConfettiBurst(
                  key: ValueKey(_celebrateSeed),
                  count: profile.particles,
                  seed: _celebrateSeed,
                ),
              ),
            if (g.isFinished && _showResult)
              Positioned.fill(
                child: ResultOverlay(
                  game: g,
                  localId: ui.localPlayerId,
                  // Online, only the host starts the next hand.
                  onNext:
                      ui.isOnline &&
                          !ref.watch(onlineProvider.select((s) => s.isHost))
                      ? null
                      : () => ref
                            .read(gameControllerProvider.notifier)
                            .nextHand(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _deck(TableLayout layout) {
    final w = layout.otherCardWidth;
    return Positioned(
      left: layout.deckCenter.dx - w / 2,
      top: layout.deckCenter.dy - cardHeightFor(w) / 2,
      child: Entrance(
        delay: const Duration(milliseconds: 350),
        offset: Offset.zero,
        scaleFrom: 0.5,
        curve: Curves.easeOutBack,
        child: Stack(
          children: [
            for (var i = 3; i >= 0; i--)
              Transform.translate(
                offset: Offset(i * 1.2, -i * 1.2),
                child: CardBack(width: w),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pot(TableLayout layout, GameState g) {
    return Positioned(
      left: layout.potCenter.dx - TableLayout.potBase.width / 2,
      top: layout.potCenter.dy - TableLayout.potBase.height / 2,
      width: TableLayout.potBase.width,
      height: TableLayout.potBase.height,
      child: Entrance(
        delay: const Duration(milliseconds: 450),
        offset: Offset.zero,
        scaleFrom: 0.6,
        curve: Curves.easeOutBack,
        child: Transform.scale(
          scale: layout.potScale,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChipStack(amount: g.pot),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'POT ',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        AnimatedCounter(
                          value: g.pot,
                          duration: _profile.d(
                            const Duration(milliseconds: 450),
                          ),
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Stake ${formatChips(g.stake)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _seatAt(
    GameState g,
    GameUiState ui,
    TableLayout layout,
    int i,
    int local,
    AnimationProfile profile,
  ) {
    final p = g.players[i];
    final isLocal = p.id == ui.localPlayerId;
    final c = layout.seatCenter(i, local, g.players.length);
    final turn =
        !g.isFinished && g.pendingSideShow == null && g.currentIndex == i;
    final deadline = ui.deadline;
    final remaining = turn && deadline != null
        ? deadline.difference(DateTime.now())
        : null;

    return Positioned(
      left: c.dx,
      top: c.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Entrance(
          // Seats pop in one after another, starting with the local player.
          delay: Duration(
            milliseconds: 250 + 90 * ((i - local) % g.players.length),
          ),
          offset: Offset.zero,
          scaleFrom: 0.5,
          curve: Curves.easeOutBack,
          child: Transform.scale(
            scale: layout.unit,
            child: SeatView(
              player: p,
              isLocal: isLocal,
              isTurn: turn,
              isDealer: i == g.dealerIndex,
              isWinner: g.isFinished && g.winnerIds.contains(p.id),
              avatarSize: SeatMetrics.avatar,
              cardWidth: isLocal
                  ? SeatMetrics.localCard
                  : SeatMetrics.otherCard,
              visibleCards: _dealt?[p.id] ?? 3,
              flipDuration: profile.d(AppDurations.cardFlip),
              turnRemaining: remaining == null || remaining.isNegative
                  ? null
                  : remaining,
              turnTotal: Duration(seconds: g.settings.turnSeconds),
              onWarningTick: (_) =>
                  ref.read(feedbackServiceProvider).timerWarning(),
              glow: profile.glow,
            ),
          ),
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
    return RepaintBoundary(child: CustomPaint(painter: _FeltPainter(layout)));
  }
}

class _FeltPainter extends CustomPainter {
  _FeltPainter(this.layout);
  final TableLayout layout;

  static const _brass = Color(0xFFD9A93F);
  static const _brassLight = Color(0xFFF6DC8C);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: layout.center,
      width: layout.feltRadiusX * 2,
      height: layout.feltRadiusY * 2,
    );
    RRect stadium(double inflate) {
      final r = rect.inflate(inflate);
      return RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * 0.5));
    }

    final felt = stadium(0);
    final rail = stadium(18);
    final unit = layout.unit;

    // Soft drop shadow so the table floats above the room.
    canvas.drawRRect(
      rail.shift(Offset(0, 14 * unit)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.65)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 22 * unit),
    );

    // Polished wood rail: warm gradient, grain lines and a lit top edge.
    canvas.drawRRect(
      rail,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8A5A2E), Color(0xFF5A3719), Color(0xFF2E1A0B)],
          stops: [0, 0.5, 1],
        ).createShader(rail.outerRect),
    );
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRRect(rail),
        Path()..addRRect(felt),
      ),
    );
    final grain = Paint()
      ..color = Colors.black.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    final lightGrain = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (double y = rail.top; y < rail.bottom; y += 5) {
      final wobble = math.sin(y * 0.15) * 3;
      canvas.drawLine(
        Offset(rail.left, y + wobble),
        Offset(rail.right, y - wobble),
        ((y ~/ 5) % 3 == 0) ? lightGrain : grain,
      );
    }
    canvas.restore();
    // Bevel: light on the outer top edge, dark on the bottom.
    canvas.drawRRect(
      rail.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.45),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.5),
          ],
        ).createShader(rail.outerRect),
    );

    // Brass studs set into the rail.
    final studPath = Path()..addRRect(stadium(9));
    final studPaint = Paint()..color = _brass;
    final studShine = Paint()..color = _brassLight;
    for (final m in studPath.computeMetrics()) {
      final spacing = 30 * unit;
      final count = math.max(8, (m.length / spacing).round());
      for (var i = 0; i < count; i++) {
        final t = m.getTangentForOffset(m.length * i / count);
        if (t == null) continue;
        canvas.drawCircle(t.position, 2.6 * unit + 0.6, studPaint);
        canvas.drawCircle(
          t.position.translate(-0.7, -0.7),
          1.1 * unit + 0.3,
          studShine,
        );
      }
    }

    // Padded cushion between the rail and the felt.
    canvas.drawRRect(
      stadium(3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1F3B2C), Color(0xFF0B1A12)],
        ).createShader(rail.outerRect),
    );

    // Felt: spotlight from above, then a dark vignette toward the edges.
    canvas.drawRRect(
      felt,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.25),
          radius: 0.95,
          colors: [AppColors.feltLight, AppColors.felt, AppColors.feltDark],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipRRect(felt);
    // Fine woven texture.
    final weave = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    final step = 7.0;
    for (double d = -rect.height; d < rect.width + rect.height; d += step) {
      canvas.drawLine(
        Offset(rect.left + d, rect.top),
        Offset(rect.left + d + rect.height, rect.bottom),
        weave,
      );
    }
    // Faint card-suit emblem in the middle of the table.
    final c = layout.center;
    final emblem = math.min(rect.width, rect.height) * 0.16;
    final emblemColor = Colors.white.withValues(alpha: 0.07);
    final spread = rect.width * 0.27;
    for (final (i, suit) in Suit.values.indexed) {
      final dx = (i - 1.5) * (spread / 1.5) * 0.9;
      canvas.save();
      canvas.translate(c.dx + dx, c.dy);
      paintSuit(canvas, suit, emblem * (i.isEven ? 1 : 0.85), emblemColor);
      canvas.restore();
    }
    canvas.drawRRect(
      felt,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 1.0,
          colors: [
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.38),
          ],
          stops: const [0, 0.62, 1],
        ).createShader(rect),
    );
    canvas.restore();

    // Double gold inlay on the felt.
    for (final (inset, alpha, w) in const [
      (13.0, 0.55, 1.6),
      (18.0, 0.25, 1.0),
    ]) {
      canvas.drawRRect(
        felt.deflate(inset),
        Paint()
          ..color = _brass.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w,
      );
    }
    // Pot circle where the chips land.
    final pot = layout.potCenter;
    canvas.drawOval(
      Rect.fromCenter(
        center: pot,
        width: 150 * layout.potScale,
        height: 118 * layout.potScale,
      ),
      Paint()
        ..color = _brass.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_FeltPainter old) => old.layout.size != layout.size;
}
