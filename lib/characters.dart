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

class Drop {
  final double chance;
  final ItemFactory item;

  const Drop(this.chance, this.item);
}

typedef BrainFactory = Brain Function(Character character, Random random);

class EnemyDescriptor {
  final String name;
  final int maxHealth;
  final Drawable drawable;
  final List<Drop> drops;
  final BrainFactory brain;

  const EnemyDescriptor({
    required this.name,
    required this.brain,
    required this.maxHealth,
    required this.drawable,
    required this.drops,
  });

  Enemy spawn(Position location, {int? seed}) {
    final enemy = Enemy(location, this);
    enemy.brain = brain(enemy, Random(seed));
    return enemy;
  }
}

class Enemies {
  Enemies._();

  static const EnemyDescriptor alien = EnemyDescriptor(
    name: 'Alien',
    brain: Wanderer.new,
    maxHealth: 2,
    drops: [
      Drop(0.2, HealOne.new),
      Drop(0.1, HealAll.new),
    ],
    drawable: OrbitAnimation(
      CircularOrbit(radius: 0.1, period: Duration(seconds: 2)),
      SpriteDrawable(Sprites.alienMonster),
    ),
  );
}

class Enemy extends Character {
  final EnemyDescriptor descriptor;
  Brain? brain;

  bool get showHealthBar => currentHealth != maxHealth;

  @override
  Drawable get drawable => CompositeDrawable([
        descriptor.drawable,
        if (showHealthBar)
          HealthBarDrawable(
            currentHealth: currentHealth,
            maxHealth: maxHealth,
          ),
      ]);

  Enemy(Position location, this.descriptor)
      : super(
          location: location,
          maxHealth: descriptor.maxHealth,
          currentHealth: descriptor.maxHealth,
        );

  void update(GameState state) {
    brain?.update(state);
  }

  Item? rollForItem(Random random) {
    double roll = random.nextDouble();
    double threshold = 0.0;
    for (var drop in descriptor.drops) {
      threshold += drop.chance;
      if (roll < threshold) {
        return drop.item(location: location);
      }
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
  final Random random;

  Wanderer(this.character, this.random);

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
        final index = random.nextInt(actions.length);
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
