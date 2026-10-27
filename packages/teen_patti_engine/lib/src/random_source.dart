import 'dart:math';

/// Injectable randomness: seeded for tests/offline, cryptographic on the server.
abstract interface class RandomSource {
  /// Uniform integer in [0, max).
  int nextInt(int max);
  double nextDouble();
}

class SeededRandomSource implements RandomSource {
  SeededRandomSource(int seed) : _random = Random(seed);
  final Random _random;

  @override
  int nextInt(int max) => _random.nextInt(max);

  @override
  double nextDouble() => _random.nextDouble();
}

class SecureRandomSource implements RandomSource {
  SecureRandomSource() : _random = Random.secure();
  final Random _random;

  @override
  int nextInt(int max) => _random.nextInt(max);

  @override
  double nextDouble() => _random.nextDouble();
}
