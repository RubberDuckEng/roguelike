import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'model.dart';
import 'geometry.dart';
import 'sprite.dart';

class CellPainter {
  final Canvas canvas;
  final Size cellSize;

  CellPainter(this.canvas, this.cellSize);

  Rect rectForPosition(GridPosition position, Size cell) {
    return Rect.fromLTWH(position.x * cell.width, position.y * cell.height,
        cell.width, cell.height);
  }

  void fillCell(GridPosition position, Color color) {
    final paint = Paint();
    paint.isAntiAlias = false;
    paint.color = color;
    canvas.drawRect(rectForPosition(position, cellSize), paint);
  }

  void paintSprite(Sprite sprite, GridPosition position) {
    sprite.paint(canvas, rectForPosition(position, cellSize));
  }
}

class WorldPainter extends CustomPainter {
  final GameState gameState;

  WorldPainter(this.gameState);

  void paintBackground(Chunk chunk, CellPainter painter) {
    // allPositions does not guarentee order.
    for (var position in chunk.allGridPositions) {
      var color = chunk.isPassableLocal(position)
          ? Colors.brown.shade300
          : Colors.brown.shade600;
      painter.fillCell(position, color);
    }
  }

  void paintMob(Chunk chunk, CellPainter painter, Mob mob) {
    painter.paintSprite(mob.sprite, chunk.toLocal(mob.location));
  }

  void paintItems(Chunk chunk, CellPainter painter) {
    for (var position in chunk.allGridPositions) {
      var item = chunk.itemAtLocal(position);
      if (item != null) {
        painter.paintSprite(item.sprite, position);
      }
    }
  }

  void paintFogOfWar(Chunk chunk, CellPainter painter) {
    for (var position in chunk.allGridPositions) {
      var isRevealed = chunk.isRevealedLocal(position);
      if (!isRevealed) {
        painter.fillCell(position, Colors.black);
      } else {
        // Don't paint fog over walls to avoid changing their color.
        var isWall = chunk.getCellLocal(position).type == CellType.wall;
        if (!isWall) {
          var isLit = chunk.isLitLocal(position);
          if (!isLit) {
            painter.fillCell(position, Colors.black38);
          }
        }
      }
    }
  }

  void paintChunk(Canvas canvas, Chunk chunk, Size size) {
    final cellSize = Size(size.width / chunk.width, size.height / chunk.height);
    final painter = CellPainter(canvas, cellSize);

    paintBackground(chunk, painter);
    paintItems(chunk, painter);
    for (var mob in chunk.enemies) {
      // Only paint mobs outside the fog of war.
      if (chunk.isLit(mob.location)) {
        paintMob(chunk, painter, mob);
      }
    }
    paintMob(chunk, painter, gameState.player);
    paintFogOfWar(chunk, painter);
  }

  @override
  void paint(Canvas canvas, Size size) {
    var chunks = gameState.nearbyChunks;
    final chunkSize =
        Size(size.width / chunks.width, size.height / chunks.height);

    for (var position in chunks.allPositions) {
      // FIXME: Must be a more efficient way than this?
      canvas.save();
      canvas.translate(
          chunkSize.width * position.x, chunkSize.height * position.y);
      paintChunk(canvas, chunks.get(position)!, chunkSize);
      canvas.restore();
    }
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
    return Text("Chunk: ${gameState.visibleChunk.chunkId}");
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
