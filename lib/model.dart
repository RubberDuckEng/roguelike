import 'dart:math';

import 'geometry.dart';

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
      generator.fillUnreachableCells();
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

  void fillUnreachableCells() {
    for (var position in level.allPositions) {
      var cell = level.getCell(position);
      if (cell.isPassable) {
        if (!level.hasPathBetween(start, position)) {
          level.setCell(position, const Cell.wall());
        }
      }
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

abstract class Item {
  void onPickup(GameState state);
}

class PortalKey extends Item {
  @override
  void onPickup(GameState state) {
    state.currentLevelState.unlockExit();
  }
}

class LevelMap extends Item {
  @override
  void onPickup(GameState state) {
    state.currentLevelState.revealAll();
  }
}

class Mob {
  Position location;

  Mob.spawn(this.location);

  void hit(GameState state) {}
}

class Player extends Mob {
  int health = 10;
  List<Item> inventory;

  Player.spawn(Position location)
      : inventory = [],
        super.spawn(location);

  double get lightRadius => 1.5;

  void move(Delta delta) {
    location += delta;
  }

  @override
  void hit(GameState state) {
    health -= 1;
  }
}

class Enemy extends Mob {
  Brain? brain;

  Enemy.spawn(Position location) : super.spawn(location);

  void update(GameState state) {
    if (brain != null) {
      brain!.update(state);
    }
  }

  @override
  void hit(GameState state) {
    state.currentLevelState.removeEnemy(this);
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
      if (!state.currentLevel.isPassable(position)) {
        continue;
      }
      if (state.currentLevelState.enemyAt(position) != null) {
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

class LevelState {
  final Level level;
  final int levelIndex;
  List<Enemy> enemies;
  Grid<bool> revealed;
  Grid<Item?> itemGrid;
  bool exitUnlocked;

  LevelState.spawn(this.level, this.levelIndex, Random random)
      : enemies = [],
        revealed = Grid<bool>.filled(level.size, () => false),
        itemGrid = Grid<Item?>.filled(level.size, () => null),
        exitUnlocked = false {
    spawnEnemies(levelIndex, random);
    spawnItems(random);
  }

  void spawnEnemies(int count, Random random) {
    for (int i = 0; i < count; ++i) {
      final enemy = Enemy.spawn(getEnemySpawnLocation(random));
      enemy.brain = Wanderer(enemy);
      enemies.add(enemy);
    }
  }

  void spawnItems(Random random) {
    var keyLocation = getItemSpawnLocation(random);
    setItemAt(keyLocation, PortalKey());

    var mapLocation = getItemSpawnLocation(random);
    setItemAt(mapLocation, LevelMap());
  }

  bool isRevealed(Position position) => revealed.get(position) ?? false;

  Item? pickupItem(Position position) {
    var item = itemGrid.get(position);
    if (item != null) {
      itemGrid.set(position, null);
    }
    return item;
  }

  void setItemAt(Position position, Item item) {
    itemGrid.set(position, item);
  }

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

  Position getEnemySpawnLocation(Random random) {
    return _getRandomPositionWithCondition(level.size, random,
        (Position position) {
      if (!level.isPassable(position)) {
        return false;
      }
      if (position == level.enter || position == level.exit) {
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
    for (var position in level.allPositions) {
      revealed.set(position, true);
    }
  }

  bool canMove(Mob mob, Delta delta) {
    if (delta.isZero) {
      return false;
    }
    var targetPosition = mob.location + delta;
    var targetCell = level.getCell(targetPosition);
    return targetCell.isPassable;
  }

  void removeEnemy(Enemy enemy) {
    enemies.remove(enemy);
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

  Action? actionFor(Player player, Delta delta) {
    final target = player.location + delta;
    final enemy = currentLevelState.enemyAt(target);
    if (enemy != null) {
      return AttackAction(target: target, mob: player);
    }
    if (currentLevelState.canMove(player, delta)) {
      return MoveAction(destination: player.location + delta, mob: player);
    }
    return null;
  }

  Mob? mobAt(Position position) {
    if (player.location == position) {
      return player;
    }
    return currentLevelState.enemyAt(position);
  }

  // FIXME: Not clear this belongs here?
  bool canMove(Player player, Delta delta) {
    if (delta.isZero) {
      return false;
    }
    var targetPosition = player.location + delta;
    var targetCell = currentLevel.getCell(targetPosition);
    // FIXME: Exit isn't passable w/o a key?
    return targetCell.isPassable;
  }

  void updateVisibility() {
    for (var position in currentLevel.nearbyPositions(player.location,
        radius: player.lightRadius)) {
      currentLevelState.revealed.set(position, true);
    }
  }

  void nextTurn() {
    for (var enemy in currentLevelState.enemies) {
      enemy.update(this);
    }
    var item = currentLevelState.pickupItem(player.location);
    if (item != null) {
      item.onPickup(this);
    } else if (player.location == currentLevel.exit &&
        currentLevelState.exitUnlocked) {
      spawnInLevel(_currentLevelIndex + 1, NamedLocation.entrance);
    } else if (player.location == currentLevel.enter &&
        _currentLevelIndex > 1) {
      spawnInLevel(_currentLevelIndex - 1, NamedLocation.exit);
    }
    updateVisibility();
  }
}
