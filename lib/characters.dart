import 'dart:math';

import 'package:flutter/material.dart';

import 'drawing.dart';
import 'geometry.dart';
import 'items.dart';
import 'model.dart';
import 'sprite.dart';
import 'world.dart';

abstract class Character extends Mob {
  int maxHealth;
  int currentHealth;
  Direction lastMoveDirection = Direction.up;

  Character({
    required super.location,
    required this.maxHealth,
    required this.currentHealth,
  });

  void applyHealthChange(GameState state, int delta) {
    currentHealth = max(min(currentHealth + delta, maxHealth), 0);
    if (currentHealth == 0) {
      didExhaustHealth(state);
    }
  }

  void hit(GameState state, int amount) {
    applyHealthChange(state, -amount);
  }

  void didExhaustHealth(GameState state) {}
}

class Player extends Character {
  double lightRadius = 2.5;
  bool carryingBlock = false;

  Player.spawn(Position location)
      : super(location: location, maxHealth: 10, currentHealth: 10);

  int get missingHealth => maxHealth - currentHealth;

  @override
  Drawable get drawable {
    Drawable avatar = const SpriteDrawable(Sprites.ladyBug);

    if (carryingBlock) {
      final block = TransformDrawable.rst(
        scale: 0.25,
        dx: 0.0,
        dy: -0.6,
        drawable: SolidDrawable(Colors.brown.shade600),
      );
      avatar = CompositeDrawable([avatar, block]);
    }

    return TransformDrawable.rst(
      rotation: lastMoveDirection.rotation,
      drawable: avatar,
    );
  }
}

class Enemy extends Character {
  Brain? brain;

  bool get showHealthBar => currentHealth != maxHealth;

  @override
  Drawable get drawable => CompositeDrawable([
        const OrbitAnimation(
          CircularOrbit(radius: 0.1, period: Duration(seconds: 2)),
          SpriteDrawable(Sprites.alienMonster),
        ),
        if (showHealthBar)
          HealthBarDrawable(
            currentHealth: currentHealth,
            maxHealth: maxHealth,
          ),
      ]);

  Enemy.spawn(Position location)
      : super(location: location, maxHealth: 2, currentHealth: 2);

  void update(GameState state) {
    brain?.update(state);
  }

  Item? rollForItem(Random random) {
    double chance = random.nextDouble();
    if (chance < 0.20) {
      return HealOne(location: location);
    } else if (chance < 0.30) {
      return HealAll(location: location);
    }
    return null;
  }

  @override
  void didExhaustHealth(GameState state) {
    var item = rollForItem(state.random);
    state.world.removeEnemy(this, droppedItem: item);
  }
}

abstract class Brain {
  void update(GameState state);
}

class Wanderer extends Brain {
  final Character character;
  final Random _random;

  Wanderer(this.character, {int? seed}) : _random = Random(seed);

  Iterable<GameAction> possibleActions(GameState state) sync* {
    for (var direction in Direction.values) {
      var position = character.location + direction.delta;
      if (!state.world.isPassable(position)) {
        continue;
      }
      if (state.world.enemyAt(position) != null) {
        continue;
      }
      if (state.player.location == position) {
        yield AttackAction(target: position, character: character);
      }
      yield MoveAction(
          destination: position, direction: direction, character: character);
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
  final Character character;

  const GameAction({required this.character});

  void execute(GameState state);
}

class MoveAction extends GameAction {
  final Direction direction;
  final Position destination;

  const MoveAction({
    required this.destination,
    required this.direction,
    required super.character,
  });

  @override
  void execute(GameState state) {
    final oldLocation = character.location;
    character.location = destination;
    character.lastMoveDirection = direction;
    state.didMoveCharacter(character, oldLocation);
  }
}

class AttackAction extends GameAction {
  final Position target;
  final int amount;

  const AttackAction({
    required this.target,
    required super.character,
    this.amount = 1,
  });

  @override
  void execute(GameState state) {
    state.characterAt(target)?.hit(state, amount);
  }
}

class InteractAction extends GameAction {
  final Position target;

  const InteractAction({required this.target, required super.character});

  static bool canInteractWith(GameState state, Mob mob, Position target) {
    if (mob is! Player) {
      return false;
    }
    final cell = state.world.getCell(target);
    return mob.carryingBlock && cell.isPassable ||
        (!mob.carryingBlock && cell.isWall);
  }

  @override
  void execute(GameState state) {
    final player = state.player;
    final direction = player.lastMoveDirection;
    final target = player.location + direction.delta;
    final cell = state.world.getCell(target);
    if (player.carryingBlock) {
      if (cell.isPassable) {
        state.world.setCell(target, const Cell.wall());
        player.carryingBlock = false;
      }
    } else {
      if (cell.isWall) {
        state.world.setCell(target, const Cell.empty());
        player.carryingBlock = true;
      }
    }
  }
}
