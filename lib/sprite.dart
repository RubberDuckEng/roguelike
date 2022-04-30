import 'dart:ui';

import 'package:flutter/material.dart';

abstract class Sprite {
  const Sprite();

  void paint(Canvas canvas, Rect rect);
}

@immutable
class IconSprite extends Sprite {
  final IconData data;

  const IconSprite(this.data);

  @override
  void paint(Canvas canvas, Rect rect) {
    final builder = ParagraphBuilder(
      ParagraphStyle(
        fontFamily: data.fontFamily,
        fontSize: rect.shortestSide * 0.8,
      ),
    );
    builder.addText(String.fromCharCode(data.codePoint));
    final paragraph = builder.build();
    paragraph.layout(const ParagraphConstraints(width: double.infinity));
    final iconSize = Size(paragraph.maxIntrinsicWidth, paragraph.height);
    final iconRect = Alignment.center.inscribe(iconSize, rect);
    canvas.drawParagraph(paragraph, iconRect.topLeft);
  }
}

class Sprites {
  Sprites._();

  static const Sprite key = IconSprite(IconData(0x1F511));
  static const Sprite map = IconSprite(IconData(0x1F5FA));
  static const Sprite heart = IconSprite(IconData(0x1F49C));
  static const Sprite sparkle_heart = IconSprite(IconData(0x1F496));
  static const Sprite alien_monster = IconSprite(IconData(0x1F47E));
  static const Sprite flutter_dash = IconSprite(Icons.flutter_dash);
}
