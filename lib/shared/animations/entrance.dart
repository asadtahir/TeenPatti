import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'animation_profile.dart';

/// Fades, slides and scales its child in once when it first appears. Durations follow the
/// user's animation settings, so "Reduce animations" shows the child immediately.
class Entrance extends ConsumerStatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
    this.offset = const Offset(0, 24),
    this.scaleFrom = 1,
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Where the child starts relative to its resting place.
  final Offset offset;
  final double scaleFrom;
  final Curve curve;

  @override
  ConsumerState<Entrance> createState() => _EntranceState();
}

class _EntranceState extends ConsumerState<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    final p = ref.read(animationProfileProvider);
    final delay = p.d(widget.delay);
    final total = delay + p.d(widget.duration);
    _c = AnimationController(vsync: this, duration: total);
    final start = delay.inMicroseconds / total.inMicroseconds;
    _t = CurvedAnimation(
      parent: _c,
      curve: Interval(start, 1, curve: widget.curve),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final t = _t.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: widget.offset * (1 - t),
            child: Transform.scale(
              scale: widget.scaleFrom + (1 - widget.scaleFrom) * t,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Wraps each child in an [Entrance] that starts [step] after the previous one.
List<Widget> staggered(
  List<Widget> children, {
  Duration start = Duration.zero,
  Duration step = const Duration(milliseconds: 70),
  Offset offset = const Offset(0, 22),
  Curve curve = Curves.easeOutCubic,
}) => [
  for (var i = 0; i < children.length; i++)
    Entrance(
      delay: start + step * i,
      offset: offset,
      curve: curve,
      child: children[i],
    ),
];
