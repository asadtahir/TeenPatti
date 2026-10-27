import 'package:flutter/material.dart';

import '../widgets/chip_badge.dart';

/// Number that counts up/down smoothly and pops when it changes.
class AnimatedCounter extends StatefulWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.duration = const Duration(milliseconds: 450),
  });

  final int value;
  final TextStyle? style;
  final String prefix;
  final Duration duration;

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter> with SingleTickerProviderStateMixin {
  late final AnimationController _pop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  @override
  void didUpdateWidget(AnimatedCounter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pop,
      builder: (context, child) {
        final p = _pop.value;
        final scale = 1 + 0.18 * (1 - (2 * p - 1).abs());
        return Transform.scale(scale: scale, child: child);
      },
      child: TweenAnimationBuilder<int>(
        tween: IntTween(begin: widget.value, end: widget.value),
        duration: widget.duration,
        builder: (context, v, _) => Text('${widget.prefix}${formatChips(v)}', style: widget.style),
      ),
    );
  }
}
