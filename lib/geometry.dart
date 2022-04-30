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
  int get walkingDistance => max(dx.abs(), dy.abs());

  @override
  bool operator ==(other) {
    if (other is! Delta) {
      return false;
    }
    return dx == other.dx && dy == other.dy;
  }

  @override
  int get hashCode {
    return hashValues(dx, dy);
  }
}

class Position {
  final int x;
  final int y;

  const Position(this.x, this.y);

  // FIXME: Why isn't this operator+?
  Position apply(Delta delta) => Position(x + delta.dx, y + delta.dy);

  Delta deltaTo(Position other) {
    return Delta(other.x - x, other.y - y);
  }

  @override
  String toString() => '($x, $y)';

  @override
  bool operator ==(other) {
    if (other is! Position) {
      return false;
    }
    return x == other.x && y == other.y;
  }

  @override
  int get hashCode {
    return hashValues(x, y);
  }
}

class ISize {
  final int width;
  final int height;

  const ISize(this.width, this.height);
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
