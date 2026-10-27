class GameSettings {
  const GameSettings({
    this.bootAmount = 100,
    this.maxStakeMultiple = 64,
    this.potLimitMultiple = 1000,
    this.turnSeconds = 15,
  });

  /// Mandatory entry amount every player pays into the pot.
  final int bootAmount;

  /// The blind stake can never exceed bootAmount * maxStakeMultiple.
  final int maxStakeMultiple;

  /// When the pot reaches bootAmount * potLimitMultiple, a showdown is forced.
  final int potLimitMultiple;

  final int turnSeconds;

  int get maxStake => bootAmount * maxStakeMultiple;
  int get potLimit => bootAmount * potLimitMultiple;

  Map<String, Object?> toJson() => {
        'boot': bootAmount,
        'maxStakeMultiple': maxStakeMultiple,
        'potLimitMultiple': potLimitMultiple,
        'turnSeconds': turnSeconds,
      };

  factory GameSettings.fromJson(Map<String, Object?> j) => GameSettings(
        bootAmount: j['boot'] as int,
        maxStakeMultiple: j['maxStakeMultiple'] as int,
        potLimitMultiple: j['potLimitMultiple'] as int,
        turnSeconds: j['turnSeconds'] as int,
      );
}
