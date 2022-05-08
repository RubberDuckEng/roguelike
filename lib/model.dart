import 'dart:math';

import 'characters.dart';
import 'drawing.dart';
import 'geometry.dart';
import 'grid.dart';
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

  GameState.demo({
    int? seed,
  })  : world = World(seed: seed),
        random = Random(seed) {
    player = Player.spawn(Position.zero);
    updateVisibility();
  }

  Chunk get focusedChunk => getChunk(player.location);

  Chunk getChunk(Position position) =>
      world.get(ChunkId.fromPosition(position));

  Grid<Chunk> get activeChunks {
    var offset = Delta(focusedChunk.chunkId.x - 1, focusedChunk.chunkId.y - 1);
    return Grid.filled(
        const ISize(3, 3),
        (position) =>
            world.get(ChunkId(offset.dx + position.x, offset.dy + position.y)));
  }

  void draw(Drawing drawing) {
    for (var chunk in activeChunks.cells) {
      chunk.draw(drawing);
    }
    player.draw(drawing);
  }

  bool get playerDead => player.currentHealth <= 0;

  GameAction? actionFor(Player player, LogicalEvent logical) {
    if (logical.interact) {
      var direction = player.lastMoveDirection;
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
      return AttackAction(target: target, character: player);
    }
    if (world.isPassable(target)) {
      return MoveAction(
        destination: player.location + direction.delta,
        direction: direction,
        character: player,
      );
    }
    return null;
  }

  Character? characterAt(Position position) {
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
    for (var chunk in activeChunks.cells) {
      chunk.update(this);
    }
    var item = world.pickupItem(player.location);
    if (item != null) {
      item.onPickup(this);
    }
    updateVisibility();
  }
}
