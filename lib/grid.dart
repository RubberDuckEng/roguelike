import 'geometry.dart';

class GridPosition {
  final int x;
  final int y;

  const GridPosition(this.x, this.y);

  static const zero = GridPosition(0, 0);

  @override
  bool operator ==(other) {
    if (other is! GridPosition) {
      return false;
    }
    return x == other.x && y == other.y;
  }

  @override
  int get hashCode => Object.hash(x, y);
}

class Grid<T> {
  final List<List<T>> _cells;

  const Grid(this._cells);

  Grid.filled(ISize size, T Function(GridPosition position) create)
      : _cells = List.generate(
            size.height,
            (y) =>
                List.generate(size.width, (x) => create(GridPosition(x, y))));

  ISize get size => ISize(width, height);
  int get width => _cells.first.length;
  int get height => _cells.length;

  void set(GridPosition position, T cell) {
    if (position.y < 0 || position.y >= _cells.length) {
      throw ArgumentError.value(position);
    }
    final row = _cells[position.y];
    if (position.x < 0 || position.x >= row.length) {
      throw ArgumentError.value(position);
    }
    row[position.x] = cell;
  }

  T? get(GridPosition position) {
    if (position.x < 0 || position.x >= width) {
      return null;
    }
    if (position.y < 0 || position.y >= height) {
      return null;
    }
    return _get(position);
  }

  T _get(GridPosition position) {
    final row = _cells[position.y];
    return row[position.x];
  }

  Iterable<GridPosition> get allPositions sync* {
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        yield GridPosition(x, y);
      }
    }
  }

  Iterable<T> get cells => allPositions.map((position) => _get(position));

  Iterable<List<T>> get cellsByRow => _cells;
}
