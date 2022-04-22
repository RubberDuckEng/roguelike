import 'dart:math';
import 'package:flutter/material.dart';

class Delta {
  final int dx;
  final int dy;

  const Delta(this.dx, this.dy);

  const Delta.zero()
      : dx = 0,
        dy = 0;

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

enum CellType {
  empty,
  wall,
  outOfBounds,
}

class Cell {
  final CellType type;

  const Cell.empty() : type = CellType.empty;
  const Cell.wall() : type = CellType.wall;
  const Cell.outOfBounds() : type = CellType.outOfBounds;

  bool get isPassable => type == CellType.empty;

  String toCharRepresentation() {
    switch (type) {
      case CellType.empty:
        return ' ';
      case CellType.wall:
        return 'w';
      case CellType.outOfBounds:
        return '☠️';
    }
  }
}

class Level {
  final List<List<Cell>> _cells;

  Level(this._cells);

  Level.empty(ISize size)
      : _cells = List.generate(
            size.height,
            (index) =>
                List.generate(size.width, (index) => const Cell.empty()));

  // Should this be on an LevelBuilder instead?
  void setCell(Position position, Cell cell) {
    if (position.y < 0 || position.y >= _cells.length) {
      throw ArgumentError.value(position);
    }
    final row = _cells[position.y];
    if (position.x < 0 || position.x >= row.length) {
      throw ArgumentError.value(position);
    }
    row[position.x] = cell;
  }

  Cell getCell(Position position) {
    if (position.y < 0 || position.y >= _cells.length) {
      return const Cell.outOfBounds();
    }
    final row = _cells[position.y];
    if (position.x < 0 || position.x >= row.length) {
      return const Cell.outOfBounds();
    }
    return row[position.x];
  }

  bool isPassable(Position position) => getCell(position).isPassable;

  Iterable<Position> traversableNeighbors(Position position) sync* {
    var deltas = const [Delta.up(), Delta.down(), Delta.left(), Delta.right()];
    for (var delta in deltas) {
      var neighbor = position.apply(delta);
      if (isPassable(neighbor)) {
        yield neighbor;
      }
    }
  }

  bool hasPathBetween(Position start, Position end) {
    final visited = {};
    final queue = [];
    queue.add(start);
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (current == end) {
        return true;
      }
      visited[current] = true;
      for (var next in traversableNeighbors(current)) {
        if (visited.containsKey(next)) {
          continue;
        }
        queue.add(next);
      }
    }
    return false;
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    for (var row in _cells) {
      for (var cell in row) {
        buffer.write(cell.toCharRepresentation());
      }
      buffer.write('\n');
    }
    return buffer.toString();
  }
}

class MazeLevelGenerator {
  final ISize size;
  final Position start;
  final Position end;
  final Level level;
  final Random _random;

  MazeLevelGenerator({
    required this.size,
    required this.start,
    required this.end,
    int? seed,
  })  : level = Level.empty(size),
        _random = Random(seed);

  Position getRandomPosition() {
    var area = size.width * size.height;
    var offset = _random.nextInt(area);
    var width = (offset / size.width).truncate();
    var height = offset % size.height;
    return Position(width, height);
  }

  void addWall() {
    while (true) {
      final position = getRandomPosition();
      if (!level.getCell(position).isPassable) {
        continue;
      }
      final oldCell = level.getCell(position);
      level.setCell(position, const Cell.wall());
      if (level.hasPathBetween(start, end)) {
        return;
      }
      level.setCell(position, oldCell);
    }
  }

  void addManyWalls(int numberOfWalls) {
    for (int i = 0; i < numberOfWalls; ++i) {
      addWall();
    }
  }
}

class World {
  final ISize size;
  final Level level;

  // Avoids refactoring for ISize, could be removed.
  int get width => size.width;
  int get height => size.height;

  World(this.size) : level = Level.empty(size);
}

class Player {
  Position location;

  Player.spawn(this.location);

  void move(Delta delta) {
    location = location.apply(delta);
  }
}

abstract class Brain {
  void update();
}

class RandomMover extends Brain {
  List<Delta> possibleMoves = [
    const Delta.up(),
    const Delta.down(),
    const Delta.left(),
    const Delta.right(),
  ];

  final Mob mob;
  final Random _random;

  RandomMover(this.mob, {int? seed}) : _random = Random(seed);

  @override
  void update() {
    final index = _random.nextInt(possibleMoves.length);
    mob.move(possibleMoves[index]);
  }
}

class Mob {
  Position location;
  Brain? brain;

  Mob.spawn(this.location);

  void move(Delta delta) {
    location = location.apply(delta);
  }

  void update() {
    if (brain != null) {
      brain!.update();
    }
  }
}

class GameState {
  World world;
  Player player;
  List<Mob> mobs;

  GameState.demo()
      : world = World(const ISize(10, 10)),
        player = Player.spawn(const Position(3, 4)),
        mobs = [] {
    final mob = Mob.spawn(const Position(2, 1));
    mob.brain = RandomMover(mob);
    mobs.add(mob);
  }

  void nextTurn() {
    List<Mob> doomed = [];
    for (var mob in mobs) {
      mob.update();
      if (mob.location == player.location) {
        doomed.add(mob);
      }
    }
    for (var mob in doomed) {
      mobs.remove(mob);
    }
  }
}
