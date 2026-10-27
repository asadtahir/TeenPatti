import 'dart:math' as math;
import 'dart:ui';

/// Pure geometry for the table; everything derives from the available size so it
/// scales across phones, tablets and desktop windows.
class TableLayout {
  TableLayout(this.size);
  final Size size;

  Offset get center => Offset(size.width / 2, size.height * 0.44);
  double get radiusX => size.width * 0.40;
  double get radiusY => size.height * 0.30;

  Offset get potCenter => center;
  Offset get deckCenter => Offset(center.dx - radiusX * 0.62, center.dy - radiusY * 0.1);

  /// Seat centre for [index] relative to [localIndex]; the local player sits at the bottom
  /// and the rest follow clockwise.
  Offset seatCenter(int index, int localIndex, int count) {
    final k = (index - localIndex) % count;
    final angle = math.pi / 2 + 2 * math.pi * k / count;
    final dy = center.dy + radiusY * 1.12 * math.sin(angle);
    return Offset(
      center.dx + radiusX * 1.12 * math.cos(angle),
      // Keep whole seats (cards + avatar + labels) on screen.
      dy.clamp(math.min(70.0, size.height / 2), math.max(size.height - 100, size.height / 2)),
    );
  }

  /// Seat sizing scales with the shortest side so cards never overflow.
  double get avatarSize => (size.shortestSide * 0.13).clamp(40.0, 76.0);
  double get otherCardWidth => (size.shortestSide * 0.075).clamp(22.0, 44.0);
  double get myCardWidth => (size.shortestSide * 0.16).clamp(50.0, 96.0);
}
