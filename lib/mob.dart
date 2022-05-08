import 'dart:math';

import 'package:flutter/material.dart';

import 'geometry.dart';
import 'model.dart';
import 'drawing.dart';
import 'sprite.dart';
import 'items.dart';
import 'world.dart';

abstract class Mob {
  Position location;
  Direction lastMoveDirection = Direction.up;

  Mob.spawn(this.location);

  Drawable get drawable;

  void draw(Drawing drawing) {
    drawing.add(this, drawable, location);
  }

  void hit(GameState state) {}
}

class Player extends Mob {
  int maxHealth = 10;
  int currentHealth = 10;
  double lightRadius = 2.5;
  bool carryingBlock = false;

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

  @override
  void draw(Drawing drawing) {
    var avatar = drawable;

    if (carryingBlock) {
      final block = TransformDrawable.rst(
        scale: 0.25,
        dx: 0.0,
        dy: -0.6,
        drawable: SolidDrawable(Colors.brown.shade600),
      );
      avatar = CompositeDrawable([avatar, block]);
    }

    avatar = TransformDrawable.rst(
      rotation: lastMoveDirection.rotation,
      drawable: avatar,
    );

    drawing.add(this, avatar, location);
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

  @override
  void draw(Drawing drawing) {
    var avatar = OrbitAnimation(
      const CircularOrbit(radius: 0.1, period: Duration(seconds: 2)),
      drawable,
    );

    drawing.add(this, avatar, location);
  }
}

abstract class Brain {
  void update(GameState state);
}

class Wanderer extends Brain {
  final Mob mob;
  final Random _random;

  Wanderer(this.mob, {int? seed}) : _random = Random(seed);

  Iterable<GameAction> possibleActions(GameState state) sync* {
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

  GameAction? selectAction(GameState state) {
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

abstract class GameAction {
  final Mob mob;

  const GameAction({required this.mob});

  void execute(GameState state);
}

class MoveAction extends GameAction {
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

class AttackAction extends GameAction {
  final Position target;

  const AttackAction({required this.target, required super.mob});

  @override
  void execute(GameState state) {
    state.mobAt(target)?.hit(state);
  }
}

class InteractAction extends GameAction {
  final Position target;

  const InteractAction({required this.target, required super.mob});

  static bool canInteractWith(GameState state, Mob mob, Position target) {
    if (mob is! Player) {
      return false;
    }
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
