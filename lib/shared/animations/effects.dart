import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../widgets/card_views.dart';
import '../widgets/chip_disc.dart';

/// A fire-and-forget visual effect rendered by [EffectsLayer].
abstract class Effect {
  Effect({this.delay = Duration.zero, required this.duration, this.onDone});

  final Duration delay;
  final Duration duration;
  final VoidCallback? onDone;

  /// [t] runs 0..1 over [duration], after [delay].
  Widget build(BuildContext context, double t);
}

/// A card back flying from the deck to a seat, with a little spin.
class FlyingCardEffect extends Effect {
  FlyingCardEffect({
    required this.from,
    required this.to,
    required this.cardWidth,
    required this.spin,
    super.delay,
    required super.duration,
    super.onDone,
  });

  final Offset from;
  final Offset to;
  final double cardWidth;
  final double spin;

  @override
  Widget build(BuildContext context, double t) {
    final e = Curves.easeOutCubic.transform(t);
    final pos = Offset.lerp(from, to, e)!;
    final h = cardWidth / AppCardSize.aspect;
    return Positioned(
      left: pos.dx - cardWidth / 2,
      top: pos.dy - h / 2,
      child: Transform.rotate(
        angle: spin * e,
        child: Transform.scale(
          scale: 0.7 + 0.3 * e,
          child: CardBack(width: cardWidth),
        ),
      ),
    );
  }
}

/// A small stack of chips travelling between two points with a bounce on arrival.
class ChipFlightEffect extends Effect {
  ChipFlightEffect({
    required this.from,
    required this.to,
    this.count = 3,
    this.chipSize = 22,
    super.delay,
    required super.duration,
    super.onDone,
  });

  final Offset from;
  final Offset to;
  final int count;
  final double chipSize;

  @override
  Widget build(BuildContext context, double t) {
    final children = <Widget>[];
    for (var i = 0; i < count; i++) {
      // Each chip lags slightly behind the previous one.
      final lt = ((t * (1 + count * 0.18)) - i * 0.18).clamp(0.0, 1.0);
      final e = Curves.easeInOutCubic.transform(lt);
      final arc = math.sin(lt * math.pi) * -18;
      final pos = Offset.lerp(from, to, e)! + Offset(0, arc);
      // Tiny scale pop as the chip lands.
      final pop = lt > 0.85 ? 1 + 0.25 * math.sin((lt - 0.85) / 0.15 * math.pi) : 1.0;
      children.add(Positioned(
        left: pos.dx - chipSize / 2 + (i - count / 2) * 3,
        top: pos.dy - chipSize / 2,
        child: Opacity(
          opacity: lt <= 0 ? 0 : 1,
          child: Transform.scale(scale: pop, child: ChipDisc(size: chipSize)),
        ),
      ));
    }
    return Stack(clipBehavior: Clip.none, children: children);
  }
}

/// "CALL 100" style label that rises and fades.
class FloatingTextEffect extends Effect {
  FloatingTextEffect({
    required this.at,
    required this.text,
    this.color = AppColors.gold,
    super.delay,
    super.duration = const Duration(milliseconds: 1100),
    super.onDone,
  });

  final Offset at;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context, double t) {
    final opacity = t < 0.2 ? t / 0.2 : (t > 0.7 ? (1 - t) / 0.3 : 1.0);
    final rise = Curves.easeOut.transform(t) * 36;
    final scale = 0.8 + 0.2 * Curves.easeOutBack.transform((t * 3).clamp(0.0, 1.0));
    return Positioned(
      left: at.dx - 70,
      top: at.dy - rise,
      width: 140,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: color.withValues(alpha: 0.8)),
                ),
                child: Text(text,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EffectsController extends ChangeNotifier {
  final List<Effect> _effects = [];
  List<Effect> get effects => List.unmodifiable(_effects);

  void add(Effect e) {
    _effects.add(e);
    notifyListeners();
  }

  void _remove(Effect e) {
    if (_effects.remove(e)) notifyListeners();
  }

  void clear() {
    _effects.clear();
    notifyListeners();
  }
}

/// Renders live effects above the table. Each runs on its own controller.
class EffectsLayer extends StatelessWidget {
  const EffectsLayer({super.key, required this.controller});
  final EffectsController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Stack(
          clipBehavior: Clip.none,
          children: [
            for (final e in controller.effects)
              _EffectRunner(
                key: ObjectKey(e),
                effect: e,
                onFinished: () => controller._remove(e),
              ),
          ],
        ),
      ),
    );
  }
}

class _EffectRunner extends StatefulWidget {
  const _EffectRunner({super.key, required this.effect, required this.onFinished});
  final Effect effect;
  final VoidCallback onFinished;

  @override
  State<_EffectRunner> createState() => _EffectRunnerState();
}

class _EffectRunnerState extends State<_EffectRunner> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    final total = widget.effect.delay + widget.effect.duration;
    _c = AnimationController(vsync: this, duration: total)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          widget.effect.onDone?.call();
          widget.onFinished();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.effect;
    final total = (e.delay + e.duration).inMicroseconds;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final elapsed = _c.value * total;
          if (elapsed < e.delay.inMicroseconds) return const SizedBox.shrink();
          final t = ((elapsed - e.delay.inMicroseconds) / e.duration.inMicroseconds)
              .clamp(0.0, 1.0);
          return Stack(clipBehavior: Clip.none, children: [e.build(context, t)]);
        },
      ),
    );
  }
}
