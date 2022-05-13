import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fast_noise/fast_noise.dart';

import 'characters.dart';
import 'drawing.dart';
import 'geometry.dart';
import 'grid.dart';
import 'items.dart';

const ISize kChunkSize = ISize(10, 10);

enum CellType {
  empty,
  wall,
}

class Cell {
  final CellType type;
  final double value;

  const Cell(this.type, this.value);

  const Cell.empty()
      : type = CellType.empty,
        value = 0;
  const Cell.wall()
      : type = CellType.wall,
        value = 0;

  bool get isPassable => type == CellType.empty;
  bool get isWall => type == CellType.wall;

  String toCharRepresentation() {
    switch (type) {
      case CellType.empty:
        return ' ';
      case CellType.wall:
        return 'w';
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
  final List<Enemy> enemies = [];
  final List<Item> items = [];
  final Grid<Cell> cells;
  final Grid<bool> mapped;
  final Grid<bool> lit;

  Chunk(this.cells, this.chunkId, PerlinNoise noise)
      : mapped = Grid<bool>.filled(cells.size, (_) => false),
        lit = Grid<bool>.filled(cells.size, (_) => false) {
    for (var position in allPositions) {
      final value =
          noise.getPerlin2(position.x.toDouble(), position.y.toDouble());
      cells.set(toLocal(position),
          value < 0.0 ? const Cell.wall() : const Cell.empty());
      // cells.set(toLocal(position), Cell(CellType.empty, value));
    }

    // addManyWalls(10, random);
    // spawnEnemies(2, random);
    // spawnItems(random);
  }

  void draw(Drawing drawing) {
    // allPositions does not guarentee order.
    for (var position in allPositions) {
      final color =
          isPassable(position) ? Colors.brown.shade300 : Colors.brown.shade600;
      // final cell = getCell(position);
      // final color =
      //     cell.value < 0.0 ? Colors.brown.shade300 : Colors.brown.shade600;
      // // print("value: ${cell.value}");

      //Color.fromARGB(255, 0, (255 * cell.value).round(), 0);
      drawing.addBackground(SolidDrawable(color), position);
    }

    for (var item in items) {
      item.draw(drawing);
    }

    for (var enemy in enemies) {
      if (isLit(enemy.location)) {
        enemy.draw(drawing);
      } else {
        drawing.add(enemy, const InvisibleDrawable(), enemy.location);
      }
    }

    // for (var position in allPositions) {
    //   final isRevealed = this.isRevealed(position);
    //   if (!isRevealed) {
    //     drawing.addForeground(const SolidDrawable(Colors.black), position);
    //   } else {
    //     // Don't paint fog over walls to avoid changing their color.
    //     final isWall = getCell(position).type == CellType.wall;
    //     if (!isWall) {
    //       final isLit = this.isLit(position);
    //       if (!isLit) {
    //         drawing.addForeground(
    //             const SolidDrawable(Colors.black38), position);
    //       }
    //     }
    //   }
    // }
  }

  void addWall(Random random) {
    final position = _getRandomGridPositionWithCondition(
        size, random, (position) => _getCellLocal(position).isPassable);
    cells.set(position, const Cell.wall());
  }

  void addManyWalls(int numberOfWalls, random) {
    for (int i = 0; i < numberOfWalls; ++i) {
      addWall(random);
    }
  }

  void spawnEnemies(int count, Random random) {
    for (int i = 0; i < count; ++i) {
      enemies.add(Enemies.alien.spawn(getEnemySpawnLocation(random)));
    }
  }

  void spawnOneItem(ItemFactory item, Random random, {double chance = 1.0}) {
    if (random.nextDouble() < chance) {
      items.add(item(location: getItemSpawnLocation(random)));
    }
  }

  void spawnItems(Random random) {
    spawnOneItem(AreaReveal.new, random, chance: 0.50);
    spawnOneItem(HealOne.new, random, chance: 0.70);
    spawnOneItem(HealAll.new, random, chance: 0.20);
    spawnOneItem(Torch.new, random, chance: 0.05);
    spawnOneItem(MaxHealthUp.new, random, chance: 0.05);
  }

  ISize get size => cells.size;

  bool _isPassableLocal(GridPosition position) =>
      _getCellLocal(position).isPassable;
  bool isPassable(Position position) => _isPassableLocal(toLocal(position));

  GridPosition toLocal(Position position) {
    return GridPosition(position.x - chunkId.x * kChunkSize.width,
        position.y - chunkId.y * kChunkSize.height);
  }

  Position toGlobal(GridPosition position) {
    return Position(position.x + chunkId.x * kChunkSize.width,
        position.y + chunkId.y * kChunkSize.height);
  }

  Rect get bounds => toGlobal(GridPosition.zero).toOffset() & size.toSize();

  bool contains(Position position) => ChunkId.fromPosition(position) == chunkId;

  Cell _getCellLocal(GridPosition position) => cells.get(position)!;
  Cell getCell(Position position) => _getCellLocal(toLocal(position));

  void setCell(Position position, Cell cell) {
    cells.set(toLocal(position), cell);
  }

  Iterable<Position> get allPositions =>
      allGridPositions.map((position) => toGlobal(position));
  Iterable<GridPosition> get allGridPositions => cells.allPositions;

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

  bool isRevealed(Position position) => mapped.get(toLocal(position)) ?? false;
  bool isLit(Position position) => lit.get(toLocal(position)) ?? false;

  Item? itemAt(Position position) {
    for (var item in items) {
      if (item.location == position) {
        return item;
      }
    }
    return null;
  }

  Position getItemSpawnLocation(Random random) {
    return toGlobal(_getRandomGridPositionWithCondition(size, random,
        (GridPosition position) {
      if (!_isPassableLocal(position)) {
        return false;
      }
      return itemAt(toGlobal(position)) == null;
    }));
  }

  Position getEnemySpawnLocation(Random random) {
    return toGlobal(_getRandomGridPositionWithCondition(size, random,
        (GridPosition position) {
      if (!_isPassableLocal(position)) {
        return false;
      }
      return enemyAt(toGlobal(position)) == null;
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
  final PerlinNoise noise;

  World({int? seed})
      : seed = seed ?? 0,
        noise = PerlinNoise(
          seed: seed ?? 1337,
          gain: 1.0,
          frequency: 0.1,
        );

  Chunk get(ChunkId id) => _map.putIfAbsent(id, () => _generateChunk(id));

  Chunk _chunkAt(Position position) => get(ChunkId.fromPosition(position));

  Chunk _generateChunk(ChunkId chunkId) {
    // This Random is wrong, use noise or similar instead.
    // final random = Random(chunkId.hashCode ^ seed);
    final cells = Grid.filled(kChunkSize, (_) => const Cell.empty());
    return Chunk(cells, chunkId, noise);
  }

  bool isPassable(Position position) => _chunkAt(position).isPassable(position);
  Enemy? enemyAt(Position position) => _chunkAt(position).enemyAt(position);
  Cell getCell(Position position) => _chunkAt(position).getCell(position);
  void setCell(Position position, Cell cell) =>
      _chunkAt(position).setCell(position, cell);

  Item? pickupItem(Position position) {
    final chunk = _chunkAt(position);
    final item = chunk.itemAt(position);
    if (item != null) {
      chunk.items.remove(item);
    }
    return item;
  }

  void removeEnemy(Enemy enemy, {Item? droppedItem}) {
    final chunk = _chunkAt(enemy.location);
    chunk.enemies.remove(enemy);
    if (droppedItem != null && chunk.itemAt(enemy.location) == null) {
      chunk.items.add(droppedItem);
    }
  }
}
