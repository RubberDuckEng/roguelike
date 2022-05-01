import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'model.dart';
import 'geometry.dart';
import 'sprite.dart';

class CellPainter {
  final Canvas canvas;
  final Size cellSize;

  CellPainter(this.canvas, this.cellSize);

  Rect rectForPosition(Position position, Size cell) {
    return Rect.fromLTWH(position.x * cell.width, position.y * cell.height,
        cell.width, cell.height);
  }

  Offset offsetForPosition(Position position, Size cellSize) {
    return Offset((position.x + 0.5) * cellSize.width,
        (position.y + 0.5) * cellSize.height);
  }

  void fillCell(Position position, Color color) {
    final paint = Paint();
    paint.isAntiAlias = false;
    paint.color = color;
    canvas.drawRect(rectForPosition(position, cellSize), paint);
  }

  void paintSprite(Sprite sprite, Position position) {
    sprite.paint(canvas, rectForPosition(position, cellSize));
  }
}

class WorldPainter extends CustomPainter {
  final GameState gameState;

  WorldPainter(this.gameState);

  void paintBackground(CellPainter painter) {
    var level = gameState.currentLevel;
    // allPositions does not guarentee order.
    for (var position in level.allPositions) {
      var color = level.isPassable(position)
          ? Colors.brown.shade300
          : Colors.brown.shade600;
      painter.fillCell(position, color);
    }
  }

  void paintPortal(CellPainter painter, Position position, Color color) {
    painter.fillCell(position, color);
  }

  void paintPlayer(CellPainter painter, Player player) {
    painter.paintSprite(player.sprite, player.location);
  }

  void paintMob(CellPainter painter, Mob mob) {
    painter.paintSprite(mob.sprite, mob.location);
  }

  // FIXME: Does this belong on Item?
  Sprite spriteForItem(Item item) {
    if (item is PortalKey) {
      return Sprites.key;
    } else if (item is LevelMap) {
      return Sprites.map;
    } else if (item is HealOne) {
      return Sprites.heart;
    } else if (item is HealAll) {
      return Sprites.sparkleHeart;
    } else if (item is Torch) {
      return Sprites.torch;
    }
    throw ArgumentError.value(item);
  }

  void paintItems(CellPainter painter) {
    for (var position in gameState.currentLevel.allPositions) {
      var item = gameState.currentLevelState.itemAt(position);
      if (item != null) {
        var sprite = spriteForItem(item);
        painter.paintSprite(sprite, position);
      }
    }
  }

  // This doesn't actually do fog of war yet, just mapped or not.
  void paintFogOfWar(CellPainter painter) {
    for (var position in gameState.currentLevel.allPositions) {
      var isRevealed = gameState.currentLevelState.isRevealed(position);
      if (!isRevealed) {
        painter.fillCell(position, Colors.black);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = Size(size.width / gameState.world.width,
        size.height / gameState.world.height);
    final painter = CellPainter(canvas, cellSize);

    paintBackground(painter);
    if (gameState.currentLevelNumber != 0) {
      painter.paintSprite(Sprites.previousLevel, gameState.currentLevel.enter);
    }

    var exitSprite = Sprites.openExit;
    if (!gameState.currentLevelState.exitUnlocked) {
      exitSprite = Sprites.closedExit;
    }
    painter.paintSprite(exitSprite, gameState.currentLevel.exit);
    paintItems(painter);
    for (var mob in gameState.currentLevelState.enemies) {
      paintMob(painter, mob);
    }
    paintPlayer(painter, gameState.player);
    paintFogOfWar(painter);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class HealthPip extends StatelessWidget {
  final bool full;
  const HealthPip({super.key, this.full = true});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.favorite,
      color: full ? Colors.pink : Colors.grey,
    );
  }
}

class HealthIndicator extends StatelessWidget {
  final GameState gameState;

  const HealthIndicator({
    super.key,
    required this.gameState,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < gameState.player.currentHealth; ++i)
          const HealthPip(full: true),
        for (int i = 0; i < gameState.player.missingHealth; ++i)
          const HealthPip(full: false),
      ],
    );
  }
}

class LevelIndicator extends StatelessWidget {
  final GameState gameState;

  const LevelIndicator({
    super.key,
    required this.gameState,
  });

  @override
  Widget build(BuildContext context) {
    return Text("Level: ${gameState.currentLevelNumber}");
  }
}

class HeadsUpDisplay extends StatelessWidget {
  final GameState gameState;

  const HeadsUpDisplay({
    super.key,
    required this.gameState,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black54,
        border: Border.all(color: Colors.white),
      ),
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HealthIndicator(gameState: gameState),
          const SizedBox.square(dimension: 8.0),
          LevelIndicator(gameState: gameState),
        ],
      ),
    );
  }
}

class WorldView extends StatelessWidget {
  final GameState gameState;

  const WorldView({Key? key, required this.gameState}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: WorldPainter(gameState),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: HeadsUpDisplay(gameState: gameState),
        )
      ],
    );
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roguelike',
      theme: ThemeData.dark(),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

Delta deltaFromKey(RawKeyDownEvent event) {
  if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
    return const Delta.left();
  } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
    return const Delta.right();
  } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
    return const Delta.up();
  } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
    return const Delta.down();
  }
  return const Delta.zero();
}

class _GamePageState extends State<GamePage> {
  final focusNode = FocusNode();
  GameState gameState = GameState.demo();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.blueGrey,
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.0,
          child: RawKeyboardListener(
            autofocus: true,
            focusNode: focusNode,
            onKey: (event) {
              if (event is RawKeyDownEvent) {
                var delta = deltaFromKey(event);
                var playerAction = gameState.actionFor(gameState.player, delta);
                setState(() {
                  if (playerAction != null) {
                    playerAction.execute(gameState);
                  }
                  gameState.nextTurn();
                });
              }
            },
            child: WorldView(
              gameState: gameState,
            ),
          ),
        ),
      ),
    );
  }
}
