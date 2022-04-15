import 'dart:math';
import 'package:flutter/material.dart';

class Delta {
  final int dx;
  final int dy;

  const Delta(this.dx, this.dy);

  const Delta.zero()
      : dx = 0,
        dy = 0;

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

class World {
  final int width;
  final int height;

  World({required this.width, required this.height});
}

class Player {
  Position location;

  Player.spawn(this.location);

  void move(Delta delta) {
    location = location.apply(delta);
  }
}

abstract class Brain {
  void update();
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

  @override
  void update() {
    final index = _random.nextInt(possibleMoves.length);
    mob.move(possibleMoves[index]);
  }
}

class Mob {
  Position location;
  Brain? brain;

  Mob.spawn(this.location);

  void move(Delta delta) {
    location = location.apply(delta);
  }

  void update() {
    if (brain != null) {
      brain!.update();
    }
  }
}

class GameState {
  World world;
  Player player;
  List<Mob> mobs;

  GameState.demo()
      : world = World(width: 10, height: 10),
        player = Player.spawn(const Position(3, 4)),
        mobs = [] {
    final mob = Mob.spawn(const Position(2, 1));
    mob.brain = RandomMover(mob);
    mobs.add(mob);
  }

  void nextTurn() {
    List<Mob> doomed = [];
    for (var mob in mobs) {
      mob.update();
      if (mob.location == player.location) {
        doomed.add(mob);
      }
    }
    for (var mob in doomed) {
      mobs.remove(mob);
    }
  }
}
