import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/settings_controller.dart';
import '../../features/settings/settings_model.dart';

/// Scales every animation from the user's quality and accessibility settings.
class AnimationProfile {
  const AnimationProfile({
    required this.speed,
    required this.particles,
    required this.glow,
    required this.reduced,
  });

  /// Duration multiplier (smaller = faster).
  final double speed;
  final int particles;
  final bool glow;
  final bool reduced;

  Duration d(Duration base) {
    if (reduced) return const Duration(milliseconds: 1);
    final ms = (base.inMilliseconds * speed).round();
    return Duration(milliseconds: ms < 1 ? 1 : ms);
  }

  factory AnimationProfile.from(AppSettings s) {
    if (s.reduceMotion) {
      return const AnimationProfile(speed: 0, particles: 0, glow: false, reduced: true);
    }
    return switch (s.graphicsQuality) {
      GraphicsQuality.low => const AnimationProfile(speed: 0.6, particles: 0, glow: false, reduced: false),
      GraphicsQuality.medium => const AnimationProfile(speed: 0.85, particles: 24, glow: true, reduced: false),
      GraphicsQuality.high => const AnimationProfile(speed: 1, particles: 48, glow: true, reduced: false),
      GraphicsQuality.ultra => const AnimationProfile(speed: 1, particles: 90, glow: true, reduced: false),
    };
  }
}

final animationProfileProvider = Provider<AnimationProfile>(
  (ref) => AnimationProfile.from(ref.watch(settingsProvider)),
);

/// Whether the OS also asks for reduced motion.
bool systemReducesMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;
