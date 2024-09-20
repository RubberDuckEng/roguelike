import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'drawing.dart';
import 'geometry.dart';
import 'model.dart';

class GameController extends ChangeNotifier {
  GameState state = GameState();

  Drawing get drawing => _drawing.value!;
  Rect get window => _window.value!;
  Duration elapsed = const Duration();

  late Ticker _idleTicker;
  late AnimationController _turnAnimationController;

  final DrawingTween _drawingTween = DrawingTween();
  late Animation<Drawing?> _drawing;

  final RectTween _windowTween = RectTween();
  late Animation<Rect?> _window;

  GameController(TickerProvider vsync) {
    _idleTicker = vsync.createTicker(_tick)..start();
    _turnAnimationController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 200),
      debugLabel: 'Turn',
    );

    final initialDrawing = _draw();
    _drawingTween
      ..begin = initialDrawing
      ..end = initialDrawing;
    _drawing = _drawingTween.animate(_turnAnimationController);

    final initialWindow = _getWindow();
    _windowTween
      ..begin = initialWindow
      ..end = initialWindow;
    _window = _windowTween.animate(_turnAnimationController);
  }

  @override
  void dispose() {
    _idleTicker.dispose();
    _turnAnimationController.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    this.elapsed = elapsed;
    notifyListeners();
  }

  LogicalEvent? _logicalEventFor(KeyDownEvent event) {
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

  Drawing _draw() {
    final drawing = Drawing();
    state.draw(drawing);
    return drawing;
  }

  Rect _getWindow() => state.focusedChunk.bounds.inflate(5.0);

  void _update() {
    _drawingTween
      ..begin = drawing
      ..end = _draw();
    _windowTween
      ..begin = window
      ..end = _getWindow();

    _turnAnimationController
      ..stop()
      ..value = 0.0
      ..forward();

    notifyListeners();
  }

  void handleKeyEvent(KeyDownEvent event) {
    var logical = _logicalEventFor(event);
    if (logical == null) {
      return;
    }
    var playerAction = state.actionFor(state.player, logical);
    if (playerAction != null) {
      playerAction.execute(state);
    }
    state.nextTurn();
    _update();
  }

  void newGame() {
    state = GameState();
    _update();
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
  bool shouldRepaint(covariant WorldPainter oldDelegate) {
    return controller != oldDelegate.controller;
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
    return Text("Chunk: ${gameState.focusedChunk.chunkId}");
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

class MenuOverlay extends StatelessWidget {
  const MenuOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(decoration: const BoxDecoration(color: Colors.black26)),
        const Column(
          children: [
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
