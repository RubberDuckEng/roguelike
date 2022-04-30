import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'model.dart';
import 'geometry.dart';

class WorldPainter extends CustomPainter {
  final GameState gameState;

  WorldPainter(this.gameState);

  void paintBackground(Canvas canvas, Size cellSize) {
    final paint = Paint();
    paint.isAntiAlias = false;
    paint.style = PaintingStyle.fill;
    for (int i = 0; i < gameState.world.width; ++i) {
      for (int j = 0; j < gameState.world.height; ++j) {
        var cell = gameState.currentLevel.getCell(Position(i, j));
        if (cell.isPassable) {
          paint.color = Colors.brown.shade300;
        } else {
          paint.color = Colors.blue.shade300;
        }
        canvas.drawRect(rectForPosition(Position(i, j), cellSize), paint);
      }
    }
  }

  void paintPortal(
      Canvas canvas, Position position, Color color, Size cellSize) {
    final paint = Paint();
    paint.isAntiAlias = false;
    paint.color = color;
    canvas.drawRect(rectForPosition(position, cellSize), paint);
  }

  Rect rectForPosition(Position position, Size cell) {
    return Rect.fromLTWH(position.x * cell.width, position.y * cell.height,
        cell.width, cell.height);
  }

  Offset offsetForPosition(Position position, Size cellSize) {
    return Offset((position.x + 0.5) * cellSize.width,
        (position.y + 0.5) * cellSize.height);
  }

  void paintPlayer(Canvas canvas, Size cellSize) {
    var paint = Paint();
    paint.color = Colors.orange.shade500;
    var rect = rectForPosition(gameState.player.location, cellSize);
    canvas.drawCircle(rect.center, rect.width / 2.0, paint);
  }

  void paintMob(Canvas canvas, Size cellSize, Mob mob) {
    var paint = Paint();
    paint.color = Colors.red.shade500;
    var rect = rectForPosition(mob.location, cellSize);
    canvas.drawCircle(rect.center, rect.width / 2.0, paint);
  }

  void paintItems(Canvas canvas, Size cellSize) {
    final paint = Paint();
    paint.isAntiAlias = false;
    paint.style = PaintingStyle.fill;
    for (int i = 0; i < gameState.world.width; ++i) {
      for (int j = 0; j < gameState.world.height; ++j) {
        var item = gameState.currentLevelState.itemAt(Position(i, j));
        if (item != null) {
          if (item is PortalKey) {
            paint.color = Colors.pink.shade300;
          } else if (item is LevelMap) {
            paint.color = Colors.yellow.shade300;
          }
          canvas.drawRect(rectForPosition(Position(i, j), cellSize), paint);
        }
      }
    }
  }

  // This doesn't actually do fog of war yet, just mapped or not.
  void paintFogOfWar(Canvas canvas, Size cellSize) {
    final paint = Paint();
    paint.isAntiAlias = false;
    paint.style = PaintingStyle.fill;
    for (int i = 0; i < gameState.world.width; ++i) {
      for (int j = 0; j < gameState.world.height; ++j) {
        var isRevealed = gameState.currentLevelState.isRevealed(Position(i, j));
        if (!isRevealed) {
          paint.color = Colors.black;
          canvas.drawRect(rectForPosition(Position(i, j), cellSize), paint);
        }
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = Size(size.width / gameState.world.width,
        size.height / gameState.world.height);
    paintBackground(canvas, cellSize);
    paintPortal(
        canvas, gameState.currentLevel.enter, Colors.green.shade500, cellSize);
    var exitColor = Colors.purple.shade500;
    if (!gameState.currentLevelState.exitUnlocked) {
      exitColor = Colors.black38;
    }
    paintPortal(canvas, gameState.currentLevel.exit, exitColor, cellSize);
    paintItems(canvas, cellSize);
    for (var mob in gameState.currentLevelState.enemies) {
      paintMob(canvas, cellSize, mob);
    }
    paintPlayer(canvas, cellSize);
    paintFogOfWar(canvas, cellSize);
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
