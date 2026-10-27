import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/widgets/chip_badge.dart';
import '../../../shared/widgets/premium_button.dart';
import '../../../shared/widgets/table_background.dart';
import '../../profile/profile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
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
                  Row(children: [
                    const CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.surfaceHigh,
                        child: Icon(Icons.person, color: AppColors.gold)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                        child: Text(profile.username,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.title)),
                    ChipBadge(amount: profile.chips),
                    IconButton(
                      tooltip: 'Settings',
                      icon: const Icon(Icons.settings),
                      onPressed: () => context.push('/settings'),
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.xxl),
                  const Text(AppConstants.appName,
                      textAlign: TextAlign.center, style: AppText.display),
                  const Text('TEEN PATTI CARD GAME', style: AppText.caption),
                  const SizedBox(height: AppSpacing.xxl),
                  PremiumButton(
                    label: 'PLAY',
                    icon: Icons.play_arrow_rounded,
                    height: 72,
                    onPressed: () => context.push('/lobby'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PremiumButton(
                    label: 'OFFLINE',
                    icon: Icons.smart_toy_outlined,
                    style: PremiumButtonStyle.secondary,
                    onPressed: () => context.push('/offline'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PremiumButton(
                    label: 'ONLINE',
                    icon: Icons.public,
                    style: PremiumButtonStyle.secondary,
                    onPressed: () => context.push('/lobby'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PremiumButton(
                    label: 'FRIENDS',
                    icon: Icons.group_outlined,
                    style: PremiumButtonStyle.secondary,
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Friends arrive with online mode.'))),
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
