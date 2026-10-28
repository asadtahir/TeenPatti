import 'dart:math' as math;
import 'dart:ui';

/// Natural (unscaled) dimensions of a seat. The table scales every seat by
/// [TableLayout.unit], so these are the single source of truth for what fits where.
abstract final class SeatMetrics {
  static const avatar = 48.0;
  static const otherCard = 30.0;
  static const localCard = 58.0;

  /// Bounding box of an opponent seat: fanned cards, avatar with turn ring, name pill, status.
  static const other = Size(96, 176);

  /// Bounding box of the local seat (bigger cards and a "YOUR TURN" label).
  static const local = Size(134, 232);
}

/// Pure geometry for the table. Seats are placed on an ellipse that is derived from the
/// seat sizes themselves, so no seat can leave the screen or overlap its neighbours.
class TableLayout {
  TableLayout(this.size);

  final Size size;
  static const margin = 4.0;

  /// Uniform scale applied to every seat. Limited by whichever axis is tighter.
  late final double unit = math.max(
    0.3,
    math.min(math.min(size.width / 370, size.height / 650), 1.6),
  );

  Size get otherSize => SeatMetrics.other * unit;
  Size get localSize => SeatMetrics.local * unit;

  double get _ringX =>
      math.max(0.0, size.width / 2 - otherSize.width / 2 - margin);
  double get _ringY => math.max(
    0.0,
    (size.height - localSize.height / 2 - otherSize.height / 2 - 2 * margin) /
        2,
  );

  /// Centre of the seat ellipse (and of the felt, pot and deck).
  Offset get center => Offset(
    size.width / 2,
    (size.height + otherSize.height / 2 - localSize.height / 2) / 2,
  );

  /// Felt is a little smaller than the seat ring so seats sit on its rail.
  double get feltRadiusX => _ringX * 0.8;
  double get feltRadiusY => _ringY * 0.84;

  Offset get potCenter => center;

  /// Natural size of the pot widget; it is scaled by [potScale] about its centre.
  static const potBase = Size(120, 98);
  double get potScale => unit.clamp(0.6, 1.3);
  Rect get potRect => Rect.fromCenter(
    center: center,
    width: potBase.width * potScale,
    height: potBase.height * potScale,
  );

  double get otherCardWidth => SeatMetrics.otherCard * unit;

  /// The deck sits just above the pot.
  Rect get deckRect {
    final w = otherCardWidth + 6;
    final h = w / 0.714 + 6;
    return Rect.fromCenter(
      center: Offset(center.dx, potRect.top - h / 2 - 4),
      width: w,
      height: h,
    );
  }

  Offset get deckCenter => deckRect.center;

  /// Seat centre for [index] relative to [localIndex]; the local player sits at the bottom
  /// and the rest follow clockwise.
  Offset seatCenter(int index, int localIndex, int count) {
    final k = (index - localIndex) % count;
    final angle = math.pi / 2 + 2 * math.pi * k / count;
    return Offset(
      center.dx + _ringX * math.cos(angle),
      center.dy + _ringY * math.sin(angle),
    );
  }

  /// On-screen rectangle occupied by the seat at [index].
  Rect seatRect(int index, int localIndex, int count) {
    final isLocal = index == localIndex;
    return Rect.fromCenter(
      center: seatCenter(index, localIndex, count),
      width: (isLocal ? localSize : otherSize).width,
      height: (isLocal ? localSize : otherSize).height,
    );
  }
}
