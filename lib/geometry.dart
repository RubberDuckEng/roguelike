import 'dart:math';
import 'dart:ui';

class Delta {
  final int dx;
  final int dy;

  const Delta(this.dx, this.dy);

  const Delta.zero()
      : dx = 0,
        dy = 0;

  bool get isZero => this == const Delta.zero();

  const Delta.up()
      : dx = 0,
        dy = -1;
  const Delta.down()
      : dx = 0,
        dy = 1;
  const Delta.left()
      : dx = -1,
        dy = 0;
  const Delta.right()
      : dx = 1,
        dy = 0;

  @override
  String toString() => '<Δ$dx, Δ$dy>';

  double get magnitude => sqrt(dx * dx + dy * dy);
  int get manhattanDistance => dx.abs() + dy.abs();

  Direction get primaryDirection {
    var mostlyVertical = dy.abs() >= dx.abs();
    if (mostlyVertical) {
      return (dy >= 0) ? Direction.up : Direction.down;
    }
    return (dx >= 0) ? Direction.right : Direction.left;
  }

  @override
  bool operator ==(other) {
    if (other is! Delta) {
      return false;
    }
    return dx == other.dx && dy == other.dy;
  }

  @override
  int get hashCode {
    return Object.hash(dx, dy);
  }
}

class Position {
  final int x;
  final int y;

  const Position(this.x, this.y);

  static const zero = Position(0, 0);

  Delta deltaTo(Position other) {
    return Delta(other.x - x, other.y - y);
  }

  Offset toOffset() => Offset(x.toDouble(), y.toDouble());

  @override
  String toString() => '($x, $y)';

  Position operator +(Delta delta) => Position(x + delta.dx, y + delta.dy);

  @override
  bool operator ==(other) {
    if (other is! Position) {
      return false;
    }
    return x == other.x && y == other.y;
  }

  Iterable<Position> positionsInNearbyGrid(int xRadius, int yRadius) sync* {
    for (int dy = -yRadius; dy <= yRadius; dy++) {
      for (int dx = -xRadius; dx <= xRadius; dx++) {
        yield Position(x + dx, y + dy);
      }
    }
  }

  @override
  int get hashCode {
    return Object.hash(x, y);
  }
}

class ISize {
  final int width;
  final int height;

  const ISize(this.width, this.height);

  Size toSize() => Size(width.toDouble(), height.toDouble());
}

class IRect {
  final int left;
  final int right;
  final int top;
  final int bottom;

  IRect({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
  });
}

enum Direction {
  up(Delta.up()),
  down(Delta.down()),
  left(Delta.left()),
  right(Delta.right());

  final Delta delta;

  const Direction(this.delta);

  double get rotation {
    switch (this) {
      case Direction.up:
        return 0.0;
      case Direction.down:
        return pi;
      case Direction.left:
        return -pi / 2;
      case Direction.right:
        return pi / 2;
    }
  }
}
