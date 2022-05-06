import 'dart:math';
import 'dart:ui';

import 'geometry.dart';
import 'sprite.dart';

enum CellType {
  empty,
  wall,
  outOfBounds,
}

enum NamedLocation {
  center,
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

class GridPosition {
  final int x;
  final int y;

  const GridPosition(this.x, this.y);

  @override
  bool operator ==(other) {
    if (other is! GridPosition) {
      return false;
    }
    return x == other.x && y == other.y;
  }

  @override
  int get hashCode {
    return hashValues(x, y);
  }
}

class Grid<T> {
  final List<List<T>> _cells;

  Grid(this._cells);

  Grid.filled(ISize size, T Function() create)
      : _cells = List.generate(
            size.height, (index) => List.generate(size.width, (_) => create()));

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
    if (position.y < 0 || position.y >= _cells.length) {
      return null;
    }
    final row = _cells[position.y];
    if (position.x < 0 || position.x >= row.length) {
      return null;
    }
    return row[position.x];
  }
}

Position _getRandomPositionWithCondition(
    ISize size, Random random, bool Function(Position position) allowed) {
  // FIXME: Track seen positions and avoid repeats / terminate if tried all?
  while (true) {
    final position = _getRandomPosition(size, random);
    if (allowed(position)) {
      return position;
    }
  }
}

Position _getRandomPosition(ISize size, Random random) {
  var area = size.width * size.height;
  var offset = random.nextInt(area);
  var width = (offset / size.width).truncate();
  var height = offset % size.height;
  return Position(width, height);
}

abstract class Item {
  void onPickup(GameState state);

  Sprite get sprite;
}

class PortalKey extends Item {
  @override
  void onPickup(GameState state) {
    state.currentChunk.unlockExit();
  }

  @override
  Sprite get sprite => Sprites.key;
}

class LevelMap extends Item {
  @override
  void onPickup(GameState state) {
    state.currentChunk.revealAll();
  }

  @override
  Sprite get sprite => Sprites.map;
}

class HealOne extends Item {
  @override
  void onPickup(GameState state) {
    state.player.applyHealthChange(1);
  }

  @override
  Sprite get sprite => Sprites.heart;
}

class HealAll extends Item {
  @override
  void onPickup(GameState state) {
    state.player.applyHealthChange(state.player.maxHealth);
  }

  @override
  Sprite get sprite => Sprites.sparkleHeart;
}

class Torch extends Item {
  @override
  void onPickup(GameState state) {
    state.player.lightRadius += 1;
  }

  @override
  Sprite get sprite => Sprites.torch;
}

abstract class Mob {
  Position location;

  Mob.spawn(this.location);

  Sprite get sprite;

  void hit(GameState state) {}
}

class Player extends Mob {
  int maxHealth = 10;
  int currentHealth = 10;
  double lightRadius = 1.5;
  List<Item> inventory;

  Player.spawn(Position location)
      : inventory = [],
        super.spawn(location);

  int get missingHealth => maxHealth - currentHealth;

  @override
  Sprite get sprite => Sprites.bug;

  void move(Delta delta) {
    location += delta;
  }

  void applyHealthChange(int amount) {
    currentHealth += amount;
    if (currentHealth < 0) {
      // die;
    }
    currentHealth = max(min(currentHealth, maxHealth), 0);
  }

  @override
  void hit(GameState state) {
    applyHealthChange(-1);
  }
}

class Enemy extends Mob {
  Brain? brain;

  @override
  Sprite get sprite => Sprites.alienMonster;

  Enemy.spawn(Position location) : super.spawn(location);

  void update(GameState state) {
    if (brain != null) {
      brain!.update(state);
    }
  }

  Item? rollForItem(Random random) {
    double chance = random.nextDouble();
    if (chance < 0.20) {
      return HealOne();
    } else if (chance < 0.30) {
      return HealAll();
    }
    return null;
  }

  @override
  void hit(GameState state) {
    var item = rollForItem(state.random);
    state.currentChunk.removeEnemy(this, droppedItem: item);
  }
}

abstract class Brain {
  void update(GameState state);
}

class Wanderer extends Brain {
  List<Delta> possibleMoves = [
    const Delta.up(),
    const Delta.down(),
    const Delta.left(),
    const Delta.right(),
  ];

  final Mob mob;
  final Random _random;

  Wanderer(this.mob, {int? seed}) : _random = Random(seed);

  Iterable<Action> possibleActions(GameState state) sync* {
    for (var delta in possibleMoves) {
      var position = mob.location + delta;
      if (!state.currentChunk.isPassable(position)) {
        continue;
      }
      if (state.currentChunk.enemyAt(position) != null) {
        continue;
      }
      if (state.player.location == position) {
        yield AttackAction(target: position, mob: mob);
      }
      yield MoveAction(destination: position, mob: mob);
    }
  }

  Action? selectAction(GameState state) {
    var actions = possibleActions(state).toList();
    if (actions.isEmpty) {
      return null;
    }
    return actions.firstWhere(
      (element) => element is AttackAction,
      orElse: () {
        final index = _random.nextInt(actions.length);
        return actions[index];
      },
    );
  }

  @override
  void update(GameState state) {
    final action = selectAction(state);
    action?.execute(state);
  }
}

abstract class Action {
  final Mob mob;

  Action({required this.mob});

  void execute(GameState state);
}

class MoveAction extends Action {
  final Position destination;

  MoveAction({
    required this.destination,
    required super.mob,
  });

  @override
  void execute(GameState state) {
    mob.location = destination;
    // state.updateChunk();
  }
}

class AttackAction extends Action {
  final Position target;

  AttackAction({
    required this.target,
    required super.mob,
  });

  @override
  void execute(GameState state) {
    state.mobAt(target)?.hit(state);
  }
}

class Chunk {
  final Grid<Cell> cells;
  final ChunkId chunkId;
  List<Enemy> enemies;
  Grid<bool> mapped;
  Grid<bool> lit;
  Grid<Item?> itemGrid;
  bool exitUnlocked;

  Chunk(this.cells, this.chunkId, Random random)
      : enemies = [],
        mapped = Grid<bool>.filled(cells.size, () => false),
        lit = Grid<bool>.filled(cells.size, () => false),
        itemGrid = Grid<Item?>.filled(cells.size, () => null),
        exitUnlocked = false {
    spawnEnemies(2, random);
    spawnItems(random);
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
    spawnOneItem(PortalKey(), random);
    spawnOneItem(LevelMap(), random);
    spawnOneItem(HealOne(), random, chance: 0.70);
    spawnOneItem(HealAll(), random, chance: 0.20);
    spawnOneItem(Torch(), random, chance: 0.05);
  }

  ISize get size => cells.size;
  int get width => cells.width;
  int get height => cells.height;

  bool isPassable(Position position) => getCell(position).isPassable;

  GridPosition toLocal(Position position) {
    return GridPosition(position.x - chunkId.x * kChunkSize.width,
        position.y - chunkId.y * kChunkSize.height);
  }

  Position toGlobal(GridPosition position) {
    return Position(position.x + chunkId.x * kChunkSize.width,
        position.y + chunkId.y * kChunkSize.height);
  }

  Cell getCell(Position position) {
    return cells.get(toLocal(position)) ?? const Cell.outOfBounds();
  }

  void setCell(Position position, Cell cell) =>
      cells.set(toLocal(position), cell);

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

  Iterable<Position> get allPositions {
    return allGridPositions.map((position) => toGlobal(position));
  }

  Iterable<GridPosition> get allGridPositions sync* {
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        yield GridPosition(x, y);
      }
    }
  }

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
    for (var row in cells._cells) {
      for (var cell in row) {
        buffer.write(cell.toCharRepresentation());
      }
      buffer.write('\n');
    }
    return buffer.toString();
  }

  bool isRevealed(Position position) => mapped.get(toLocal(position)) ?? false;
  bool isLit(Position position) => lit.get(toLocal(position)) ?? false;

  Item? pickupItem(Position position) {
    var item = itemGrid.get(toLocal(position));
    if (item != null) {
      itemGrid.set(toLocal(position), null);
    }
    return item;
  }

  void setItemAt(Position position, Item item) {
    itemGrid.set(toLocal(position), item);
  }

  Item? itemAt(Position position) => itemGrid.get(toLocal(position));

  Position getItemSpawnLocation(Random random) {
    return _getRandomPositionWithCondition(size, random, (Position position) {
      if (!isPassable(position)) {
        return false;
      }
      return itemAt(position) == null;
    });
  }

  Position getEnemySpawnLocation(Random random) {
    return _getRandomPositionWithCondition(size, random, (Position position) {
      if (!isPassable(position)) {
        return false;
      }
      for (var enemy in enemies) {
        if (enemy.location == position) {
          return false;
        }
      }
      return true;
    });
  }

  Enemy? enemyAt(Position position) {
    for (var enemy in enemies) {
      if (enemy.location == position) {
        return enemy;
      }
    }
    return null;
  }

  void unlockExit() {
    exitUnlocked = true;
  }

  void revealAll() {
    for (var position in allGridPositions) {
      mapped.set(position, true);
    }
  }

  // bool canMove(Mob mob, Delta delta) {
  //   if (delta.isZero) {
  //     return false;
  //   }
  //   var targetPosition = mob.location + delta;
  //   var targetCell = getCell(targetPosition);
  //   return targetCell.isPassable;
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
      : x = position.x ~/ kChunkSize.width,
        y = position.y ~/ kChunkSize.height;

  @override
  String toString() {
    return '[$x,$y]';
  }

  @override
  bool operator ==(other) {
    if (other is! ChunkId) {
      return false;
    }
    return x == other.x && y == other.y;
  }

  @override
  int get hashCode {
    return hashValues(x, y);
  }
}

class World {
  final int seed;
  final Map<ChunkId, Chunk> _map = {};

  World({int? seed}) : seed = seed ?? 0;

  Chunk get(ChunkId id) {
    return _map.putIfAbsent(id, () => _generateChunk(id));
  }

  Chunk _generateChunk(ChunkId chunkId) {
    // This Random is wrong, use noise or similar instead.
    final random = Random(chunkId.hashCode ^ seed);
    final cells = Grid.filled(kChunkSize, () => const Cell.empty());
    return Chunk(cells, chunkId, random);
  }
}

ISize kChunkSize = const ISize(10, 10);

class GameState {
  late Player player;
  final World world;
  final Random random;
  Chunk get currentChunk => world.get(ChunkId.fromPosition(player.location));

  GameState.demo({
    int? seed,
  })  : world = World(seed: seed),
        random = Random(seed) {
    player = Player.spawn(const Position(0, 0));
    updateVisibility();
  }

  bool get playerDead => player.currentHealth <= 0;

  Action? actionFor(Player player, Delta delta) {
    final target = player.location + delta;
    final enemy = currentChunk.enemyAt(target);
    if (enemy != null) {
      return AttackAction(target: target, mob: player);
    }
    final targetChunkId = ChunkId.fromPosition(target);
    final targetChunk = world.get(targetChunkId);
    if (targetChunk.isPassable(target)) {
      return MoveAction(destination: player.location + delta, mob: player);
    }
    return null;
  }

  Mob? mobAt(Position position) {
    if (player.location == position) {
      return player;
    }
    return currentChunk.enemyAt(position);
  }

  void updateVisibility() {
    for (var position in currentChunk.allPositions) {
      var delta = position.deltaTo(player.location);
      var gridPosition = currentChunk.toLocal(position);
      if (delta.magnitude < player.lightRadius) {
        currentChunk.mapped.set(gridPosition, true);
        currentChunk.lit.set(gridPosition, true);
      } else {
        currentChunk.lit.set(gridPosition, false);
      }
    }
  }

  void nextTurn() {
    for (var enemy in currentChunk.enemies) {
      enemy.update(this);
    }
    var item = currentChunk.pickupItem(player.location);
    if (item != null) {
      item.onPickup(this);
    }
    // FIXME: Make it possible to walk off the edge.
    updateVisibility();
  }
}
