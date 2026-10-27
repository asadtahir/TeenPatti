import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

String formatChips(int value) {
  final s = value.abs().toString();
  final buf = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

class ChipBadge extends StatelessWidget {
  const ChipBadge({super.key, required this.amount});
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.casino, size: 18, color: AppColors.gold),
        const SizedBox(width: AppSpacing.sm),
        Text(formatChips(amount),
            style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
