import 'dart:math';

import 'package:flutter/material.dart';

import 'drawing.dart';
import 'geometry.dart';
import 'sprite.dart';
import 'items.dart';

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

abstract class Mob {
  Position location;
  Direction lastMoveDirection;
  bool carryingBlock;

  Mob.spawn(this.location)
      : lastMoveDirection = Direction.up,
        carryingBlock = false;

  Drawable get drawable;

  void draw(Drawing drawing) {
    var avatar = drawable;

    if (carryingBlock) {
      final block = TransformDrawable.rst(
        scale: 0.25,
        anchorX: 0.5,
        anchorY: 0.5,
        dx: 0.5,
        dy: -0.1,
        drawable: SolidDrawable(Colors.brown.shade600),
      );
      avatar = CompositeDrawable([avatar, block]);
    }

    final element = DrawingElement(
      drawable: avatar,
      position: VisualPosition.from(location),
    );

    drawing.add(this, element);
  }

  void hit(GameState state) {}
}

class Player extends Mob {
  int maxHealth = 10;
  int currentHealth = 10;
  double lightRadius = 2.5;

  Player.spawn(Position location) : super.spawn(location);

  int get missingHealth => maxHealth - currentHealth;

  @override
  Drawable get drawable => const SpriteDrawable(Sprites.ladyBug);

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
  Drawable get drawable => const SpriteDrawable(Sprites.alienMonster);

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
    state.getChunk(location).removeEnemy(this, droppedItem: item);
  }
}

abstract class Brain {
  void update(GameState state);
}

class Wanderer extends Brain {
  final Mob mob;
  final Random _random;

  Wanderer(this.mob, {int? seed}) : _random = Random(seed);

  Iterable<Action> possibleActions(GameState state) sync* {
    for (var direction in Direction.values) {
      var position = mob.location + direction.delta;
      if (!state.getChunk(position).isPassable(position)) {
        continue;
      }
      if (state.getChunk(position).enemyAt(position) != null) {
        continue;
      }
      if (state.player.location == position) {
        yield AttackAction(target: position, mob: mob);
      }
      yield MoveAction(destination: position, direction: direction, mob: mob);
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

  const Action({required this.mob});

  void execute(GameState state);
}

class MoveAction extends Action {
  final Direction direction;
  final Position destination;

  const MoveAction(
      {required this.destination, required this.direction, required super.mob});

  @override
  void execute(GameState state) {
    mob.location = destination;
    mob.lastMoveDirection = direction;
    // state.updateChunk();
  }
}

class AttackAction extends Action {
  final Position target;

  const AttackAction({required this.target, required super.mob});

  @override
  void execute(GameState state) {
    state.mobAt(target)?.hit(state);
  }
}

class InteractAction extends Action {
  final Position target;

  const InteractAction({required this.target, required super.mob});

  static canInteractWith(GameState state, Mob mob, Position target) {
    final targetChunk = state.world.get(ChunkId.fromPosition(target));
    final cell = targetChunk.getCell(target);
    return mob.carryingBlock && cell.isPassable ||
        (!mob.carryingBlock && cell.isWall);
  }

  @override
  void execute(GameState state) {
    final player = state.player;
    final direction = player.lastMoveDirection;
    final target = player.location + direction.delta;
    final targetChunk = state.world.get(ChunkId.fromPosition(target));
    final cell = targetChunk.getCell(target);
    if (player.carryingBlock) {
      if (cell.isPassable) {
        targetChunk.setCell(target, const Cell.wall());
        player.carryingBlock = false;
      }
    } else {
      if (cell.isWall) {
        targetChunk.setCell(target, const Cell.empty());
        player.carryingBlock = true;
      }
    }
  }
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
      drawing.addBackground(DrawingElement.fill(position, color));
    }

    for (var position in items.allPositions) {
      final item = items.get(position);
      if (item == null) {
        continue;
      }
      final element = DrawingElement(
        drawable: item.drawable,
        position: VisualPosition.from(toGlobal(position)),
      );
      drawing.add(item, element);
    }
    for (var enemy in enemies) {
      if (isLit(enemy.location)) {
        enemy.draw(drawing);
      }
    }

    for (var position in allPositions) {
      final isRevealed = this.isRevealed(position);
      if (!isRevealed) {
        drawing.addForeground(DrawingElement.fill(position, Colors.black));
      } else {
        // Don't paint fog over walls to avoid changing their color.
        final isWall = getCell(position).type == CellType.wall;
        if (!isWall) {
          final isLit = this.isLit(position);
          if (!isLit) {
            drawing
                .addForeground(DrawingElement.fill(position, Colors.black38));
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

const ISize kChunkSize = ISize(10, 10);

class LogicalEvent {
  Direction? direction;
  bool interact;

  LogicalEvent.move(this.direction) : interact = false;
  LogicalEvent.interact() : interact = true;
}

class GameState {
  late Player player;
  final World world;
  final Random random;

  GameState.demo({
    int? seed,
  })  : world = World(seed: seed),
        random = Random(seed) {
    player = Player.spawn(const Position.zero());
    updateVisibility();
  }

  Chunk get visibleChunk => getChunk(player.location);

  Chunk getChunk(Position position) =>
      world.get(ChunkId.fromPosition(position));

  Grid<Chunk> get nearbyChunks {
    var offset = Delta(visibleChunk.chunkId.x - 1, visibleChunk.chunkId.y - 1);
    return Grid.filled(
        const ISize(3, 3),
        (position) =>
            world.get(ChunkId(offset.dx + position.x, offset.dy + position.y)));
  }

  void draw(Drawing drawing) {
    for (var chunk in nearbyChunks.cells) {
      chunk.draw(drawing);
    }
    player.draw(drawing);
  }

  bool get playerDead => player.currentHealth <= 0;

  Action? actionFor(Player player, LogicalEvent logical) {
    if (logical.interact) {
      var direction = player.lastMoveDirection;
      final target = player.location + direction.delta;
      if (InteractAction.canInteractWith(this, player, target)) {
        return InteractAction(target: target, mob: player);
      }
    }

    var direction = logical.direction;
    if (direction == null) {
      return null;
    }
    final target = player.location + direction.delta;
    final targetChunk = world.get(ChunkId.fromPosition(target));
    final enemy = targetChunk.enemyAt(target);
    if (enemy != null) {
      return AttackAction(target: target, mob: player);
    }
    if (targetChunk.isPassable(target)) {
      return MoveAction(
        destination: player.location + direction.delta,
        direction: direction,
        mob: player,
      );
    }
    return null;
  }

  Mob? mobAt(Position position) {
    if (player.location == position) {
      return player;
    }
    return getChunk(position).enemyAt(position);
  }

  void revealAround(Position position, double radius) {
    var gridRadius = radius.ceil();
    for (var position
        in player.location.positionsInNearbyGrid(gridRadius, gridRadius)) {
      var delta = position.deltaTo(player.location);
      var chunk = getChunk(position);
      var gridPosition = chunk.toLocal(position);
      if (delta.magnitude < radius) {
        chunk.mapped.set(gridPosition, true);
      }
    }
  }

  void updateVisibility() {
    var radius = player.lightRadius.ceil();
    for (var position
        in player.location.positionsInNearbyGrid(radius, radius)) {
      var delta = position.deltaTo(player.location);
      var chunk = getChunk(position);
      var gridPosition = chunk.toLocal(position);
      if (delta.magnitude < player.lightRadius) {
        chunk.mapped.set(gridPosition, true);
        chunk.lit.set(gridPosition, true);
      } else {
        chunk.lit.set(gridPosition, false);
      }
    }
  }

  void nextTurn() {
    for (var enemy in visibleChunk.enemies) {
      enemy.update(this);
    }
    var item = visibleChunk.pickupItem(player.location);
    if (item != null) {
      item.onPickup(this);
    }
    updateVisibility();
  }
}
