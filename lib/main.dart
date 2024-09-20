import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'view.dart';

void main() {
  runApp(const GameApp());
}

class GameApp extends StatelessWidget {
  const GameApp({super.key});

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
    with TickerProviderStateMixin<GamePage> {
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
          child: KeyboardListener(
            autofocus: true,
            focusNode: focusNode,
            onKeyEvent: (event) {
              if (event is KeyDownEvent) {
                if (!controller.state.playerDead) {
                  controller.handleKeyEvent(event);
                } else if (event.logicalKey == LogicalKeyboardKey.space) {
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
