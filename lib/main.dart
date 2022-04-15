import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'model.dart';

class WorldPainter extends CustomPainter {
  final GameState gameState;

  WorldPainter(this.gameState);

  void paintBackground(Canvas canvas, Size size, Size cell) {
    final paint = Paint();
    paint.style = PaintingStyle.fill;
    for (int i = 0; i < gameState.world.width; ++i) {
      for (int j = 0; j < gameState.world.height; ++j) {
        paint.color = ((i + j) % 2 == 0) ? Colors.black12 : Colors.black26;
        canvas.drawRect(rectForPosition(Position(i, j), cell), paint);
      }
    }
  }

  Rect rectForPosition(Position position, Size cell) {
    return Rect.fromLTWH(position.x * cell.width, position.y * cell.height,
        cell.width, cell.height);
  }

  Offset offsetForPosition(Position position, Size cell) {
    return Offset(position.x * cell.width, position.y * cell.height);
  }

  void paintPlayer(Canvas canvas, Size cellSize) {
    var paint = Paint();
    paint.color = Colors.orange.shade500;
    canvas.drawRect(
        rectForPosition(gameState.player.location, cellSize), paint);
  }

  void paintMob(Canvas canvas, Size cellSize, Mob mob) {
    var paint = Paint();
    paint.color = Colors.red.shade500;
    canvas.drawRect(rectForPosition(mob.location, cellSize), paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = Size(size.width / gameState.world.width,
        size.height / gameState.world.height);
    paintBackground(canvas, size, cellSize);
    paintPlayer(canvas, cellSize);
    for (var mob in gameState.mobs) {
      paintMob(canvas, cellSize, mob);
    }
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

Delta moveFromKeyEvent(RawKeyDownEvent event) {
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
      body: Row(
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: RawKeyboardListener(
              autofocus: true,
              focusNode: focusNode,
              onKey: (event) {
                if (event is RawKeyDownEvent) {
                  var move = moveFromKeyEvent(event);
                  if (move != const Delta.zero()) {
                    setState(() {
                      gameState.player.move(move);
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
        ],
      ),
    );
  }
}
