import 'dart:math';
import 'package:flutter/material.dart';

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

enum CellType {
  empty,
  wall,
  outOfBounds,
}

enum NamedLocation {
  entrance,
  exit,
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

class Grid<T> {
  final List<List<T>> _cells;

  Grid(this._cells);

  Grid.filled(ISize size, T Function() create)
      : _cells = List.generate(
            size.height, (index) => List.generate(size.width, (_) => create()));

  ISize get size => ISize(width, height);
  int get width => _cells.first.length;
  int get height => _cells.length;

  void set(Position position, T cell) {
    if (position.y < 0 || position.y >= _cells.length) {
      throw ArgumentError.value(position);
    }
    final row = _cells[position.y];
    if (position.x < 0 || position.x >= row.length) {
      throw ArgumentError.value(position);
    }
    row[position.x] = cell;
  }

  T? get(Position position) {
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

class Level {
  final Grid<Cell> grid;
  final Position enter;
  final Position exit;

  // For testing
  Level(List<List<Cell>> cells, {required this.enter, required this.exit})
      : grid = Grid(cells);

  Level.empty(ISize size, {required this.enter, required this.exit})
      : grid = Grid<Cell>.filled(size, () => const Cell.empty());

  ISize get size => grid.size;
  int get width => grid.width;
  int get height => grid.height;

  bool isPassable(Position position) => getCell(position).isPassable;

  Cell getCell(Position position) =>
      grid.get(position) ?? const Cell.outOfBounds();
  void setCell(Position position, Cell cell) => grid.set(position, cell);

  Iterable<Position> traversableNeighbors(Position position) sync* {
    var deltas = const [Delta.up(), Delta.down(), Delta.left(), Delta.right()];
    for (var delta in deltas) {
      var neighbor = position.apply(delta);
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

  Iterable<Position> get allPositions sync* {
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        yield Position(x, y);
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

  Position positionForNamedLocation(NamedLocation location) {
    switch (location) {
      case NamedLocation.entrance:
        return enter;
      case NamedLocation.exit:
        return exit;
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    for (var row in grid._cells) {
      for (var cell in row) {
        buffer.write(cell.toCharRepresentation());
      }
      buffer.write('\n');
    }
    return buffer.toString();
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
    Random? random,
  })  : level = Level.empty(size, enter: start, exit: end),
        _random = random ?? Random();

  static Iterable<Level> generateLevels(
    ISize size,
    Random random, {
    Position? enter,
    int count = 1,
  }) sync* {
    var start = enter ?? _getRandomPosition(size, random);
    while (count > 0) {
      var end = _getRandomPositionWithCondition(
          size, random, (position) => position != start);
      var generator = MazeLevelGenerator(
          size: size, start: start, end: end, random: random);
      generator.addManyWalls(20);
      yield generator.level;
      count -= 1;
      start = generator.level.exit;
    }
  }

  void addWall() {
    while (true) {
      final position = _getRandomPositionWithCondition(
          size, _random, (position) => level.getCell(position).isPassable);
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
  final List<Level> levels;

  // Avoids refactoring for ISize, could be removed.
  int get width => size.width;
  int get height => size.height;

  World(this.size, this.levels);
}

enum Item {
  key,
}

class Player {
  Position location;
  List<Item> inventory;

  Player.spawn(this.location) : inventory = [];

  double get lightRadius => 1.5;

  void move(Delta delta) {
    location = location.apply(delta);
  }
}

abstract class Brain {
  void update(GameState state);
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

  Iterable<Position> legalMoves(GameState state) sync* {
    for (var delta in possibleMoves) {
      var position = mob.location.apply(delta);
      if (!state.currentLevel.isPassable(position)) {
        continue;
      }
      if (state.player.location == position) {
        continue;
      }
      if (state.currentLevelState.mobAt(position) != null) {
        continue;
      }
      yield position;
    }
  }

  @override
  void update(GameState state) {
    var positions = legalMoves(state).toList();
    if (positions.isNotEmpty) {
      final index = _random.nextInt(positions.length);
      mob.location = positions[index];
    }
  }
}

class Mob {
  Position location;
  Brain? brain;

  Mob.spawn(this.location);

  void update(GameState state) {
    if (brain != null) {
      brain!.update(state);
    }
  }
}

abstract class PlayerAction {
  // TODO: Refactor actions to work with generic mobs and make player into mob.
  final Player player;

  PlayerAction({required this.player});

  void execute(GameState state);
}

class PlayerMoveAction extends PlayerAction {
  final Position destination;

  PlayerMoveAction({
    required this.destination,
    required super.player,
  });

  @override
  void execute(GameState state) {
    // TODO: Multiplayer?
    assert(state.player == player);
    state.player.location = destination;
  }
}

class PlayerAttackAction extends PlayerAction {
  final Position target;

  PlayerAttackAction({
    required this.target,
    required super.player,
  });

  @override
  void execute(GameState state) {
    List<Mob> doomed = [];
    for (var mob in state.currentLevelState.mobs) {
      if (mob.location == target) {
        doomed.add(mob);
      }
    }
    // Could this fail if an attack and level change happen on the same action?
    for (var mob in doomed) {
      state.currentLevelState.mobs.remove(mob);
    }
  }
}

class LevelState {
  final Level level;
  final int levelIndex;
  List<Mob> mobs;
  Grid<bool> revealed;
  Grid<Item?> itemGrid;

  LevelState.spawn(this.level, this.levelIndex, Random random)
      : mobs = [],
        revealed = Grid<bool>.filled(level.size, () => false),
        itemGrid = Grid<Item?>.filled(level.size, () => null) {
    spawnMobs(levelIndex, random);
    spawnKey(random);
  }

  void spawnMobs(int count, Random random) {
    for (int i = 0; i < count; ++i) {
      final mob = Mob.spawn(getMobSpawnLocation(random));
      mob.brain = RandomMover(mob);
      mobs.add(mob);
    }
  }

  void spawnKey(Random random) {
    var keyLocation = getItemSpawnLocation(random);
    itemGrid.set(keyLocation, Item.key);
  }

  bool isRevealed(Position position) => revealed.get(position) ?? false;

  Item? itemAt(Position position) => itemGrid.get(position);

  Position getItemSpawnLocation(Random random) {
    return _getRandomPositionWithCondition(level.size, random,
        (Position position) {
      if (!level.isPassable(position)) {
        return false;
      }
      if (position == level.enter || position == level.exit) {
        return false;
      }
      return itemAt(position) == null;
    });
  }

  Position getMobSpawnLocation(Random random) {
    return _getRandomPositionWithCondition(level.size, random,
        (Position position) {
      if (!level.isPassable(position)) {
        return false;
      }
      if (position == level.enter || position == level.exit) {
        return false;
      }
      for (var mob in mobs) {
        if (mob.location == position) {
          return false;
        }
      }
      return true;
    });
  }

  Mob? mobAt(Position position) {
    for (var mob in mobs) {
      if (mob.location == position) {
        return mob;
      }
    }
    return null;
  }
}

class GameState {
  late World world;
  late Player player;
  List<LevelState> levelStates; // Should this be a sparse array or map?
  int _currentLevelIndex;
  final Random random;

  LevelState get currentLevelState => levelStates[_currentLevelIndex];
  Level get currentLevel => levelStates[_currentLevelIndex].level;
  int get currentLevelNumber => _currentLevelIndex;

  GameState.demo({
    ISize size = const ISize(10, 10),
    int? seed,
  })  : levelStates = [],
        random = Random(seed),
        _currentLevelIndex = 0 {
    world = World(
        size,
        MazeLevelGenerator.generateLevels(size, random,
                enter: _getRandomPosition(size, random))
            .toList());
    initializeMissingLevelStates(random);
    player = Player.spawn(const Position(0, 0));
    spawnInLevel(0, NamedLocation.entrance);
    updateVisibility();
  }

  void initializeMissingLevelStates(Random random) {
    for (int levelIndex = 0; levelIndex < world.levels.length; levelIndex++) {
      if (levelStates.length <= levelIndex) {
        var level = world.levels[levelIndex];
        levelStates.add(LevelState.spawn(level, levelIndex, random));
      }
    }
  }

  void spawnInLevel(int index, NamedLocation location) {
    int missing = index - world.levels.length + 1;
    if (missing > 0) {
      var start = world.levels.isNotEmpty ? world.levels.last.exit : null;
      var newLevels = MazeLevelGenerator.generateLevels(world.size, random,
              enter: start, count: missing)
          .toList();
      world.levels.addAll(newLevels);
      initializeMissingLevelStates(random);
    }
    // Do we need to tell the level the player is leaving?
    _currentLevelIndex = index;
    player.location = currentLevel.positionForNamedLocation(location);
    // Do we need to tell the level the player is returning? (e.g respawn mobs?)
  }

  PlayerAction? actionFor(Player player, Delta delta) {
    final target = player.location.apply(delta);
    var mob = currentLevelState.mobAt(target);
    if (mob != null) {
      return PlayerAttackAction(target: target, player: player);
    }
    if (canMove(player, delta)) {
      return PlayerMoveAction(
          destination: player.location.apply(delta), player: player);
    }
    return null;
  }

  // FIXME: Not clear this belongs here?
  bool canMove(Player player, Delta delta) {
    if (delta.isZero) {
      return false;
    }
    var targetPosition = player.location.apply(delta);
    var targetCell = currentLevel.getCell(targetPosition);
    return targetCell.isPassable;
  }

  void updateVisibility() {
    for (var position in currentLevel.nearbyPositions(player.location,
        radius: player.lightRadius)) {
      currentLevelState.revealed.set(position, true);
    }
  }

  void nextTurn() {
    for (var mob in currentLevelState.mobs) {
      mob.update(this);
    }
    if (player.location == currentLevel.exit) {
      spawnInLevel(_currentLevelIndex + 1, NamedLocation.entrance);
    } else if (player.location == currentLevel.enter &&
        _currentLevelIndex > 1) {
      spawnInLevel(_currentLevelIndex - 1, NamedLocation.exit);
    }
    updateVisibility();
  }
}
