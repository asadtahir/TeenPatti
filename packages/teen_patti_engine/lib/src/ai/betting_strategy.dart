import 'profile.dart';

/// Tunable thresholds derived from an [AIProfile].
class BettingStrategy {
  const BettingStrategy(this.profile);
  final AIProfile profile;

  /// Fold a seen hand weaker than this (strength percentile).
  double get foldBelow => switch (profile.personality) {
        Personality.conservative => 0.45,
        Personality.balanced => 0.35,
        Personality.aggressive => 0.25,
        Personality.bluffer => 0.30,
      };

  /// Raise a seen hand stronger than this.
  double get raiseAbove => switch (profile.personality) {
        Personality.conservative => 0.88,
        Personality.balanced => 0.72,
        Personality.aggressive => 0.55,
        Personality.bluffer => 0.62,
      };

  /// Chance of playing a weak hand as if it were strong.
  double get bluffChance {
    final base = switch (profile.personality) {
      Personality.bluffer => 0.30,
      Personality.aggressive => 0.12,
      Personality.balanced => 0.06,
      Personality.conservative => 0.01,
    };
    return switch (profile.difficulty) {
      Difficulty.easy => base * 0.3,
      Difficulty.medium => base,
      Difficulty.hard => base * 1.2,
    };
  }

  /// How wrong the AI's read of its own hand can be.
  double get noise => switch (profile.difficulty) {
        Difficulty.easy => 0.30,
        Difficulty.medium => 0.12,
        Difficulty.hard => 0.04,
      };

  /// Chance of an unforced random valid move (easy mistakes).
  double get blunderChance => switch (profile.difficulty) {
        Difficulty.easy => 0.15,
        Difficulty.medium => 0.03,
        Difficulty.hard => 0.0,
      };

  /// Base chance to look at cards on a given turn while still blind.
  double get seeChance => switch (profile.personality) {
        Personality.conservative => 0.55,
        Personality.balanced => 0.40,
        Personality.aggressive => 0.25,
        Personality.bluffer => 0.20,
      };

  /// Chance to raise while playing blind.
  double get blindRaiseChance => switch (profile.personality) {
        Personality.aggressive => 0.30,
        Personality.bluffer => 0.25,
        Personality.balanced => 0.12,
        Personality.conservative => 0.04,
      };
}
