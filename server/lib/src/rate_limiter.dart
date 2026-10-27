/// Token bucket: [capacity] burst, refilled at [perSecond].
class RateLimiter {
  RateLimiter({this.capacity = 30, this.perSecond = 15, DateTime Function()? now})
      : _now = now ?? DateTime.now,
        _tokens = capacity.toDouble() {
    _last = _now();
  }

  final int capacity;
  final double perSecond;
  final DateTime Function() _now;
  double _tokens;
  late DateTime _last;

  bool allow() {
    final t = _now();
    final dt = t.difference(_last).inMicroseconds / 1e6;
    _last = t;
    _tokens = (_tokens + dt * perSecond).clamp(0, capacity.toDouble());
    if (_tokens < 1) return false;
    _tokens -= 1;
    return true;
  }
}
