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
    Drawable avatar = const SpriteDrawable(Sprites.ant);

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
      rotation: facingDirection.rotation,
      drawable: avatar,
    );
  }
}

class Drop {
  final double chance;
  final ItemFactory item;

  const Drop(this.chance, this.item);
}

typedef BrainFactory = Brain Function(Enemy enemy, Random random);

class EnemyDescriptor {
  final String name;
  final BrainFactory brain;
  final int attackRange;
  final int maxHealth;
  final int aggroRadius;
  final List<Drop> drops;
  final Drawable drawable;

  const EnemyDescriptor({
    required this.name,
    required this.brain,
    required this.attackRange,
    required this.maxHealth,
    required this.aggroRadius,
    required this.drops,
    required this.drawable,
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
    maxHealth: 1,
    attackRange: 1,
    aggroRadius: 3,
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
  final Enemy enemy;
  final Random random;

  Wanderer(this.enemy, this.random);

  Iterable<GameAction> possibleActions(GameState state) sync* {
    final deltaToPlayer = enemy.location.deltaTo(state.player.location);
    final distanceToPlayer = deltaToPlayer.manhattanDistance;
    final descriptor = enemy.descriptor;
    if (distanceToPlayer <= descriptor.attackRange) {
      yield AttackAction(
        target: state.player.location,
        character: enemy,
        direction: deltaToPlayer.primaryDirection,
      );
    }

    final directions = [];
    if (distanceToPlayer <= descriptor.aggroRadius) {
      if (deltaToPlayer.dx < 0) {
        directions.add(Direction.left);
      }
      if (deltaToPlayer.dx > 0) {
        directions.add(Direction.right);
      }
      if (deltaToPlayer.dy < 0) {
        directions.add(Direction.up);
      }
      if (deltaToPlayer.dy > 0) {
        directions.add(Direction.down);
      }
    } else {
      directions.addAll(Direction.values);
    }

    for (var direction in directions) {
      var position = enemy.location + direction.delta;
      if (!state.world.isPassable(position)) {
        continue;
      }
      if (state.world.enemyAt(position) != null) {
        continue;
      }
      yield MoveAction(
          destination: position, direction: direction, character: enemy);
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
    character.facingDirection = direction;
    if (state.world.isPassable(destination)) {
      final oldLocation = character.location;
      character.location = destination;
      state.didMoveCharacter(character, oldLocation);
    }
  }
}

class AttackAction extends GameAction {
  final Direction direction;
  final Position target;
  final int amount;

  const AttackAction({
    required this.target,
    required super.character,
    required this.direction,
    this.amount = 1,
  });

  @override
  void execute(GameState state) {
    character.facingDirection = direction;
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
    final direction = player.facingDirection;
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
