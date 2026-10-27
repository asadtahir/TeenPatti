import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

enum PremiumButtonStyle { primary, secondary }

/// Tactile gold/glass button with a press-scale animation.
class PremiumButton extends StatefulWidget {
  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = PremiumButtonStyle.primary,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PremiumButtonStyle style;
  final double height;

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.style == PremiumButtonStyle.primary;
    final enabled = widget.onPressed != null;
    final fg = primary ? AppColors.night : AppColors.textPrimary;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: AppDurations.fast,
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Container(
              height: widget.height,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                gradient: primary
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.gold, AppColors.goldDark])
                    : null,
                color: primary ? null : AppColors.surfaceHigh,
                border: primary
                    ? null
                    : Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                boxShadow: primary ? AppShadows.glow : AppShadows.soft,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: fg),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Flexible(
                    child: Text(widget.label,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.button.copyWith(color: fg)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
