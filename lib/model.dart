import 'dart:math';

import 'characters.dart';
import 'drawing.dart';
import 'geometry.dart';
import 'world.dart';

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

  GameState({
    int? seed,
  })  : world = World(seed: seed),
        random = Random(seed) {
    player = Player.spawn(Position.zero);
    updateVisibility();
  }

  Chunk get focusedChunk => getChunk(player.location);

  Chunk getChunk(Position position) =>
      world.get(ChunkId.fromPosition(position));

  Iterable<Chunk> get activeChunks sync* {
    final chunkId = ChunkId.fromPosition(player.location);
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        yield world.get(ChunkId(chunkId.x + dx, chunkId.y + dy));
      }
    }
  }

  void draw(Drawing drawing) {
    for (var chunk in activeChunks) {
      chunk.draw(drawing);
    }
    player.draw(drawing);
  }

  bool get playerDead => player.currentHealth <= 0;

  GameAction? actionFor(Player player, LogicalEvent logical) {
    if (logical.interact) {
      var direction = player.facingDirection;
      final target = player.location + direction.delta;
      if (InteractAction.canInteractWith(this, player, target)) {
        return InteractAction(target: target, character: player);
      }
    }

    var direction = logical.direction;
    if (direction == null) {
      return null;
    }
    final target = player.location + direction.delta;
    final enemy = world.enemyAt(target);
    if (enemy != null) {
      return AttackAction(
        target: target,
        character: player,
        direction: direction,
      );
    }
    return MoveAction(
      destination: player.location + direction.delta,
      direction: direction,
      character: player,
    );
  }

  Character? characterAt(Position position) {
    if (player.location == position) {
      return player;
    }
    return world.enemyAt(position);
  }

  void didMoveCharacter(Character character, Position oldLocation) {
    // Enemies are stored per-chunk, which means we need to migrate them if they
    // move across chunk boundaries.
    if (character is! Enemy) {
      return;
    }
    final oldChunk = getChunk(oldLocation);
    final newChunk = getChunk(character.location);
    if (oldChunk == newChunk) {
      return;
    }
    oldChunk.enemies.remove(character);
    newChunk.enemies.add(character);
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
    final enemies = activeChunks.fold<List<Enemy>>(
        <Enemy>[], (enemies, chunk) => enemies..addAll(chunk.enemies));
    for (var enemy in enemies) {
      enemy.update(this);
    }
    var item = world.pickupItem(player.location);
    item?.onPickup(this);
    updateVisibility();
  }
}
