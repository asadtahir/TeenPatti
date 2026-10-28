import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/animations/entrance.dart';
import '../../../shared/widgets/chip_badge.dart';
import '../../../shared/widgets/player_avatar.dart';
import '../../../shared/widgets/premium_button.dart';
import '../../../shared/widgets/table_background.dart';
import '../../profile/profile.dart';
import 'hero_logo.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final narrow = MediaQuery.sizeOf(context).width < 360;

    return Scaffold(
      body: TableBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Entrance(
                    offset: const Offset(0, -24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.gold,
                              width: 1.5,
                            ),
                          ),
                          child: PlayerAvatar(
                            seed: profile.username,
                            size: 44,
                            highlight: true,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            profile.username,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.title,
                          ),
                        ),
                        ChipBadge(amount: profile.chips),
                        IconButton(
                          tooltip: 'Settings',
                          icon: const Icon(Icons.settings),
                          onPressed: () => context.push('/settings'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  HeroLogo(cardWidth: narrow ? 76 : 92),
                  const SizedBox(height: AppSpacing.md),
                  Entrance(
                    delay: const Duration(milliseconds: 700),
                    duration: const Duration(milliseconds: 700),
                    offset: const Offset(0, 16),
                    scaleFrom: 0.85,
                    curve: Curves.easeOutBack,
                    child: const GoldTitle(text: AppConstants.appName),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Entrance(
                    delay: const Duration(milliseconds: 850),
                    child: const Column(
                      children: [
                        Text('THE CLASSIC 3-CARD GAME', style: AppText.caption),
                        SizedBox(height: AppSpacing.sm),
                        SuitDivider(),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Entrance(
                    delay: const Duration(milliseconds: 950),
                    scaleFrom: 0.9,
                    curve: Curves.easeOutBack,
                    child: PremiumButton(
                      label: 'PLAY',
                      icon: Icons.play_arrow_rounded,
                      height: 72,
                      pulse: true,
                      onPressed: () => context.push('/lobby'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      for (final (i, tile) in [
                        _MenuTile(
                          label: 'OFFLINE',
                          icon: Icons.smart_toy_outlined,
                          onTap: () => context.push('/offline'),
                        ),
                        _MenuTile(
                          label: 'ONLINE',
                          icon: Icons.public,
                          onTap: () => context.push('/lobby'),
                        ),
                        _MenuTile(
                          label: 'FRIENDS',
                          icon: Icons.group_outlined,
                          onTap: () => ScaffoldMessenger.of(context)
                              .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Friends arrive with online mode.',
                                  ),
                                ),
                              ),
                        ),
                      ].indexed) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Entrance(
                            delay: Duration(milliseconds: 1100 + 110 * i),
                            offset: const Offset(0, 30),
                            child: tile,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Entrance(
                    delay: const Duration(milliseconds: 1500),
                    child: const Text(
                      'Virtual chips only. No real money.',
                      style: AppText.caption,
                    ),
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

/// A square-ish glass tile with an icon, used for the secondary game modes.
class _MenuTile extends StatefulWidget {
  const _MenuTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.94 : 1,
          duration: AppDurations.fast,
          curve: Curves.easeOut,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.surfaceHigh.withValues(alpha: 0.95),
                  AppColors.surface.withValues(alpha: 0.95),
                ],
              ),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: _down ? 0.9 : 0.4),
              ),
              boxShadow: AppShadows.soft,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withValues(alpha: 0.14),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(widget.icon, color: AppColors.gold),
                ),
                const SizedBox(height: AppSpacing.sm),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
