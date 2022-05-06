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
    var chunk = gameState.currentChunk;
    // allPositions does not guarentee order.
    for (var position in chunk.allPositions) {
      var color = chunk.isPassable(position)
          ? Colors.brown.shade300
          : Colors.brown.shade600;
      painter.fillCell(position, color);
    }
  }

  void paintMob(CellPainter painter, Mob mob) {
    painter.paintSprite(mob.sprite, mob.location);
  }

  void paintItems(CellPainter painter) {
    for (var position in gameState.currentChunk.allPositions) {
      var item = gameState.currentChunk.itemAt(position);
      if (item != null) {
        painter.paintSprite(item.sprite, position);
      }
    }
  }

  // This doesn't actually do fog of war yet, just mapped or not.
  void paintFogOfWar(CellPainter painter) {
    for (var position in gameState.currentChunk.allPositions) {
      var isRevealed = gameState.currentChunk.isRevealed(position);
      if (!isRevealed) {
        painter.fillCell(position, Colors.black);
      } else {
        // Don't paint fog over walls to avoid changing their color.
        var isWall =
            gameState.currentChunk.getCell(position).type == CellType.wall;
        if (!isWall) {
          var isLit = gameState.currentChunk.isLit(position);
          if (!isLit) {
            painter.fillCell(position, Colors.black38);
          }
        }
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = Size(size.width / gameState.currentChunk.width,
        size.height / gameState.currentChunk.height);
    final painter = CellPainter(canvas, cellSize);

    paintBackground(painter);
    paintItems(painter);
    for (var mob in gameState.currentChunk.enemies) {
      // Only paint mobs outside the fog of war.
      if (gameState.currentChunk.isLit(mob.location)) {
        paintMob(painter, mob);
      }
    }
    paintMob(painter, gameState.player);
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
    return Text("Chunk: ${gameState.currentChunk.chunkId}");
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
  late GameState gameState;

  @override
  void initState() {
    newGame();
    super.initState();
  }

  void newGame() {
    gameState = GameState.demo();
  }

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
