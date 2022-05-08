import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'drawing.dart';
import 'model.dart';

class GameController extends ChangeNotifier {
  GameState state = GameState.demo();

  late Drawing drawing;
  late Rect window;
  Duration elapsed = const Duration();

  late Ticker _ticker;

  GameController(TickerProvider vsync) {
    _ticker = vsync.createTicker(_tick);
    _updateDrawing();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    this.elapsed = elapsed;
    notifyListeners();
  }

  LogicalEvent? _logicalEventFor(RawKeyDownEvent event) {
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

  void _updateDrawing() {
    drawing = Drawing();
    state.draw(drawing);
    window = Rect.fromCenter(
      center: state.player.location.toOffset(),
      width: kChunkSize.width.toDouble(),
      height: kChunkSize.height.toDouble(),
    );
  }

  void handleKeyEvent(RawKeyDownEvent event) {
    var logical = _logicalEventFor(event);
    if (logical == null) {
      return;
    }
    var playerAction = state.actionFor(state.player, logical);
    if (playerAction != null) {
      playerAction.execute(state);
    }
    state.nextTurn();
    _updateDrawing();
    notifyListeners();
  }

  void newGame() {
    state = GameState.demo();
    _updateDrawing();
    notifyListeners();
  }
}

class WorldPainter extends CustomPainter {
  final GameController controller;

  WorldPainter(this.controller) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final window = controller.window;
    final cellSize = Size(
      size.width / window.width,
      size.height / window.height,
    );
    final topLeft = window.topLeft;
    final context = DrawingContext(
      canvas: canvas,
      origin: Offset(
        -topLeft.dx * cellSize.width,
        -topLeft.dy * cellSize.height,
      ),
      cellSize: cellSize,
      elapsed: controller.elapsed,
    );
    controller.drawing.paint(context);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
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

class GameView extends AnimatedWidget {
  final GameController controller;

  const GameView({super.key, required this.controller})
      : super(listenable: controller);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: WorldPainter(controller),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: HeadsUpDisplay(gameState: controller.state),
        ),
        if (controller.state.playerDead) const MenuOverlay(),
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

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  final focusNode = FocusNode();
  late GameController controller;

  @override
  void initState() {
    super.initState();
    controller = GameController(this);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
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
                if (!controller.state.playerDead) {
                  controller.handleKeyEvent(event);
                } else if (event.isKeyPressed(LogicalKeyboardKey.space)) {
                  controller.newGame();
                }
              }
            },
            child: GameView(
              controller: controller,
            ),
          ),
        ),
      ),
    );
  }
}
