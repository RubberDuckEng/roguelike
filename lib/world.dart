import 'dart:math';

import 'package:flutter/material.dart';

import 'geometry.dart';
import 'mob.dart';
import 'drawing.dart';
import 'items.dart';
import 'grid.dart';

const ISize kChunkSize = ISize(10, 10);

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
  bool get isWall => type == CellType.wall;

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

GridPosition _getRandomGridPositionWithCondition(
    ISize size, Random random, bool Function(GridPosition position) allowed) {
  // FIXME: Track seen positions and avoid repeats / terminate if tried all?
  while (true) {
    final position = _getRandomPosition(size, random);
    if (allowed(position)) {
      return position;
    }
  }
}

GridPosition _getRandomPosition(ISize size, Random random) {
  var area = size.width * size.height;
  var offset = random.nextInt(area);
  var width = (offset / size.width).truncate();
  var height = offset % size.height;
  return GridPosition(width, height);
}

class Chunk {
  final ChunkId chunkId;
  final List<Enemy> enemies;
  final Grid<Cell> cells;
  final Grid<bool> mapped;
  final Grid<bool> lit;
  final Grid<Item?> items;

  Chunk(this.cells, this.chunkId, Random random)
      : enemies = [],
        mapped = Grid<bool>.filled(cells.size, (_) => false),
        lit = Grid<bool>.filled(cells.size, (_) => false),
        items = Grid<Item?>.filled(cells.size, (_) => null) {
    addManyWalls(10, random);
    spawnEnemies(2, random);
    spawnItems(random);
  }

  void draw(Drawing drawing) {
    // allPositions does not guarentee order.
    for (var position in allPositions) {
      final color =
          isPassable(position) ? Colors.brown.shade300 : Colors.brown.shade600;
      drawing.addBackground(SolidDrawable(color), position);
    }

    for (var position in items.allPositions) {
      final item = items.get(position);
      if (item == null) {
        continue;
      }
      drawing.add(item, item.drawable, toGlobal(position));
    }
    for (var enemy in enemies) {
      if (isLit(enemy.location)) {
        enemy.draw(drawing);
      } else {
        drawing.add(enemy, const InvisibleDrawable(), enemy.location);
      }
    }

    for (var position in allPositions) {
      final isRevealed = this.isRevealed(position);
      if (!isRevealed) {
        drawing.addForeground(const SolidDrawable(Colors.black), position);
      } else {
        // Don't paint fog over walls to avoid changing their color.
        final isWall = getCell(position).type == CellType.wall;
        if (!isWall) {
          final isLit = this.isLit(position);
          if (!isLit) {
            drawing.addForeground(
                const SolidDrawable(Colors.black38), position);
          }
        }
      }
    }
  }

  void addWall(Random random) {
    final position = _getRandomGridPositionWithCondition(
        size, random, (position) => cells.get(position)!.isPassable);
    cells.set(position, const Cell.wall());
  }

  void addManyWalls(int numberOfWalls, random) {
    for (int i = 0; i < numberOfWalls; ++i) {
      addWall(random);
    }
  }

  void spawnEnemies(int count, Random random) {
    for (int i = 0; i < count; ++i) {
      final enemy = Enemy.spawn(getEnemySpawnLocation(random));
      enemy.brain = Wanderer(enemy);
      enemies.add(enemy);
    }
  }

  void spawnOneItem(Item item, Random random, {double chance = 1.0}) {
    if (random.nextDouble() < chance) {
      setItemAt(getItemSpawnLocation(random), item);
    }
  }

  void spawnItems(Random random) {
    spawnOneItem(AreaReveal(), random, chance: 0.50);
    spawnOneItem(HealOne(), random, chance: 0.70);
    spawnOneItem(HealAll(), random, chance: 0.20);
    spawnOneItem(Torch(), random, chance: 0.05);
  }

  ISize get size => cells.size;
  int get width => cells.width;
  int get height => cells.height;

  bool isPassableLocal(GridPosition position) =>
      getCellLocal(position).isPassable;
  bool isPassable(Position position) => isPassableLocal(toLocal(position));

  GridPosition toLocal(Position position) {
    return GridPosition(position.x - chunkId.x * kChunkSize.width,
        position.y - chunkId.y * kChunkSize.height);
  }

  Position toGlobal(GridPosition position) {
    return Position(position.x + chunkId.x * kChunkSize.width,
        position.y + chunkId.y * kChunkSize.height);
  }

  Rect get bounds => toGlobal(GridPosition.zero).toOffset() & size.toSize();

  Cell getCellLocal(GridPosition position) =>
      cells.get(position) ?? const Cell.outOfBounds();
  Cell getCell(Position position) => getCellLocal(toLocal(position));

  void setCellLocal(GridPosition position, Cell cell) =>
      cells.set(position, cell);
  void setCell(Position position, Cell cell) =>
      setCellLocal(toLocal(position), cell);

  Iterable<Position> traversableNeighbors(Position position) sync* {
    var deltas = const [Delta.up(), Delta.down(), Delta.left(), Delta.right()];
    for (var delta in deltas) {
      var neighbor = position + delta;
      if (isPassable(neighbor)) {
        yield neighbor;
      }
    }
  }

  Iterable<Position> nearbyPositions(Position position,
      {double radius = 1.0}) sync* {
    for (var nearby in allPositions) {
      var delta = nearby.deltaTo(position);
      if (delta.magnitude <= radius) {
        yield nearby;
      }
    }
    // Include self?
    yield position;
  }

  Iterable<Position> get allPositions =>
      allGridPositions.map((position) => toGlobal(position));
  Iterable<GridPosition> get allGridPositions => cells.allPositions;

  bool hasPathBetween(Position start, Position end) {
    if (!isPassable(start)) {
      return false;
    }
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
    for (var row in cells.cellsByRow) {
      for (var cell in row) {
        buffer.write(cell.toCharRepresentation());
      }
      buffer.write('\n');
    }
    return buffer.toString();
  }

  bool isRevealedLocal(GridPosition position) => mapped.get(position) ?? false;
  bool isRevealed(Position position) => mapped.get(toLocal(position)) ?? false;
  bool isLitLocal(GridPosition position) => lit.get(position) ?? false;
  bool isLit(Position position) => lit.get(toLocal(position)) ?? false;

  Item? pickupItem(Position position) {
    var item = items.get(toLocal(position));
    if (item != null) {
      items.set(toLocal(position), null);
    }
    return item;
  }

  void setItemAt(Position position, Item item) =>
      items.set(toLocal(position), item);

  Item? itemAtLocal(GridPosition position) => items.get(position);
  Item? itemAt(Position position) => items.get(toLocal(position));

  Position getItemSpawnLocation(Random random) {
    return toGlobal(_getRandomGridPositionWithCondition(size, random,
        (GridPosition position) {
      if (!isPassableLocal(position)) {
        return false;
      }
      return itemAtLocal(position) == null;
    }));
  }

  Position getEnemySpawnLocation(Random random) {
    return toGlobal(_getRandomGridPositionWithCondition(size, random,
        (GridPosition position) {
      if (!isPassableLocal(position)) {
        return false;
      }
      for (var enemy in enemies) {
        if (enemy.location == toGlobal(position)) {
          return false;
        }
      }
      return true;
    }));
  }

  Enemy? enemyAt(Position position) {
    for (var enemy in enemies) {
      if (enemy.location == position) {
        return enemy;
      }
    }
    return null;
  }

  // void revealAll() {
  //   for (var position in allGridPositions) {
  //     mapped.set(position, true);
  //   }
  // }

  void removeEnemy(Enemy enemy, {Item? droppedItem}) {
    enemies.remove(enemy);
    if (droppedItem != null && itemAt(enemy.location) == null) {
      setItemAt(enemy.location, droppedItem);
    }
  }
}

class ChunkId {
  final int x;
  final int y;

  const ChunkId(this.x, this.y);
  const ChunkId.origin()
      : x = 0,
        y = 0;

  ChunkId.fromPosition(Position position)
      : x = (position.x / kChunkSize.width).floor(),
        y = (position.y / kChunkSize.height).floor();

  @override
  String toString() => '[$x,$y]';

  @override
  bool operator ==(other) {
    if (other is! ChunkId) {
      return false;
    }
    return x == other.x && y == other.y;
  }

  @override
  int get hashCode => Object.hash(x, y);
}

class World {
  final int seed;
  final Map<ChunkId, Chunk> _map = {};

  World({int? seed}) : seed = seed ?? 0;

  Chunk get(ChunkId id) => _map.putIfAbsent(id, () => _generateChunk(id));

  Chunk _generateChunk(ChunkId chunkId) {
    // This Random is wrong, use noise or similar instead.
    final random = Random(chunkId.hashCode ^ seed);
    final cells = Grid.filled(kChunkSize, (_) => const Cell.empty());
    return Chunk(cells, chunkId, random);
  }
}
