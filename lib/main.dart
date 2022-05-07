import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'model.dart';
import 'painting.dart';

class WorldPainter extends CustomPainter {
  final GameState gameState;

  WorldPainter(this.gameState);

  @override
  void paint(Canvas canvas, Size size) {
    var chunks = gameState.nearbyChunks;
    final chunkSize =
        Size(size.width / chunks.width, size.height / chunks.height);

    for (var position in chunks.allPositions) {
      final targetRect = Rect.fromLTWH(
        chunkSize.width * position.x,
        chunkSize.height * position.y,
        chunkSize.width,
        chunkSize.height,
      );
      final cellPainter = CellPainter(canvas, targetRect);
      final chunkPainter = ChunkPainter(cellPainter, chunks.get(position)!);
      chunkPainter.paint(gameState);
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

class MenuOverlay extends StatefulWidget {
  const MenuOverlay({Key? key}) : super(key: key);

  @override
  State<MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<MenuOverlay> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(decoration: const BoxDecoration(color: Colors.black26)),
        Column(
          children: const [
            Text("DEAD"),
            Text("Press space to continue."),
          ],
        )
      ],
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
        ),
        if (gameState.playerDead) const MenuOverlay(),
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

LogicalEvent? logicalEventFor(RawKeyDownEvent event) {
  if (event.logicalKey == LogicalKeyboardKey.space) {
    return LogicalEvent.interact();
  }
  if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
    return LogicalEvent.move(Direction.left);
  } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
    return LogicalEvent.move(Direction.right);
  } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
    return LogicalEvent.move(Direction.up);
  } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
    return LogicalEvent.move(Direction.down);
  }
  return null;
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
    setState(() {
      gameState = GameState.demo();
    });
  }

  void handleGameKeyEvent(RawKeyDownEvent event) {
    var logical = logicalEventFor(event);
    if (logical == null) {
      return;
    }
    var playerAction = gameState.actionFor(gameState.player, logical);
    setState(() {
      if (playerAction != null) {
        playerAction.execute(gameState);
      }
      gameState.nextTurn();
    });
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
                if (!gameState.playerDead) {
                  handleGameKeyEvent(event);
                } else if (event.isKeyPressed(LogicalKeyboardKey.space)) {
                  newGame();
                }
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
