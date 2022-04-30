import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'model.dart';

class WorldPainter extends CustomPainter {
  final GameState gameState;

  WorldPainter(this.gameState);

  void paintBackground(Canvas canvas, Size cellSize) {
    final paint = Paint();
    paint.style = PaintingStyle.fill;
    for (int i = 0; i < gameState.world.width; ++i) {
      for (int j = 0; j < gameState.world.height; ++j) {
        var cell = gameState.currentLevel.getCell(Position(i, j));
        if (cell.isPassable) {
          paint.color = ((i + j) % 2 == 0) ? Colors.black12 : Colors.black26;
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

  // This doesn't actually do fog of war yet, just mapped or not.
  void paintFogOfWar(Canvas canvas, Size cellSize) {
    final paint = Paint();
    paint.style = PaintingStyle.fill;
    for (int i = 0; i < gameState.world.width; ++i) {
      for (int j = 0; j < gameState.world.height; ++j) {
        var isRevealed =
            gameState.currentLevelState.revealed.get(Position(i, j)) ?? false;
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
    paintPortal(
        canvas, gameState.currentLevel.exit, Colors.purple.shade500, cellSize);
    for (var mob in gameState.currentLevelState.mobs) {
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

class WorldView extends StatelessWidget {
  final GameState gameState;

  const WorldView({Key? key, required this.gameState}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: WorldPainter(gameState),
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Roguelike'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
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

class _MyHomePageState extends State<MyHomePage> {
  final focusNode = FocusNode();
  GameState gameState = GameState.demo();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(children: [
          Text("Level: ${gameState.currentLevelNumber}"),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: RawKeyboardListener(
                autofocus: true,
                focusNode: focusNode,
                onKey: (event) {
                  if (event is RawKeyDownEvent) {
                    var delta = deltaFromKey(event);
                    var playerAction =
                        gameState.actionFor(gameState.player, delta);
                    if (playerAction != null) {
                      setState(() {
                        playerAction.execute(gameState);
                        gameState.nextTurn();
                      });
                    }
                  }
                },
                child: WorldView(
                  gameState: gameState,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
