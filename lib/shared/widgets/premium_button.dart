import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../features/game/presentation/feedback_service.dart';
import '../animations/ambient.dart';

enum PremiumButtonStyle { primary, secondary }

/// Tactile gold/glass button with a press-scale animation. With [pulse] the primary button
/// breathes and a light sweeps across it, to draw the eye to the main action.
class PremiumButton extends ConsumerStatefulWidget {
  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = PremiumButtonStyle.primary,
    this.height = 56,
    this.pulse = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PremiumButtonStyle style;
  final double height;
  final bool pulse;

  @override
  ConsumerState<PremiumButton> createState() => _PremiumButtonState();
}

/// Slides a gradient horizontally across its bounds ([percent] -1..1).
class _Slide extends GradientTransform {
  const _Slide(this.percent);
  final double percent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * percent, 0, 0);
}

class _PremiumButtonState extends ConsumerState<PremiumButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.style == PremiumButtonStyle.primary;
    final enabled = widget.onPressed != null;
    final fg = primary ? AppColors.night : AppColors.textPrimary;

    Widget body(double t) {
      final glow = widget.pulse
          ? [
              BoxShadow(
                color: const Color(0x88E8B84A),
                blurRadius: 16 + 14 * t,
                spreadRadius: 1 + 2 * t,
              ),
            ]
          : AppShadows.glow;
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          gradient: primary
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.gold, AppColors.goldDark],
                )
              : null,
          color: primary ? null : AppColors.surfaceHigh,
          border: primary
              ? null
              : Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
          boxShadow: primary ? glow : AppShadows.soft,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.pulse && enabled)
                const Positioned.fill(child: _Shine()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: fg),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.button.copyWith(color: fg),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget button = body(0);
    if (widget.pulse && enabled) {
      button = LoopAnimation(
        period: const Duration(milliseconds: 1600),
        builder: (context, t, _) => body(Curves.easeInOut.transform(t)),
      );
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: enabled
            ? () {
                ref.read(feedbackServiceProvider).click();
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: AppDurations.fast,
          curve: Curves.easeOut,
          child: Opacity(opacity: enabled ? 1 : 0.45, child: button),
        ),
      ),
    );
  }
}

/// A soft diagonal band of light that sweeps across the button every few seconds.
class _Shine extends StatelessWidget {
  const _Shine();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LoopAnimation(
        period: const Duration(milliseconds: 3200),
        reverse: false,
        builder: (context, t, _) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: const [
                Color(0x00FFFFFF),
                Color(0x55FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: const [0.4, 0.5, 0.6],
              transform: _Slide(-1.6 + 3.2 * t),
            ),
          ),
        ),
      ),
    );
  }
}
