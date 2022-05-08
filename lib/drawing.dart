import 'dart:collection';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'geometry.dart';
import 'sprite.dart';

double _lerpDouble(double a, double b, double t) {
  return a * (1.0 - t) + b * t;
}

class VisualPosition {
  final double x;
  final double y;

  const VisualPosition(this.x, this.y);

  VisualPosition.from(Position position)
      : x = position.x.toDouble(),
        y = position.y.toDouble();

  @override
  bool operator ==(other) {
    if (other is! VisualPosition) {
      return false;
    }
    return x == other.x && y == other.y;
  }

  @override
  int get hashCode => Object.hash(x, y);

  VisualPosition operator *(double operand) =>
      VisualPosition(x * operand, y * operand);

  static VisualPosition? lerp(VisualPosition? a, VisualPosition? b, double t) {
    if (b == null) {
      if (a == null) {
        return null;
      } else {
        return a * (1.0 - t);
      }
    } else {
      if (a == null) {
        return b * t;
      } else {
        return VisualPosition(
            _lerpDouble(a.x, b.x, t), _lerpDouble(a.y, b.y, t));
      }
    }
  }
}

class DrawingContext {
  final Canvas canvas;
  final Offset origin;
  final Size cellSize;

  DrawingContext({
    required this.canvas,
    required this.origin,
    required this.cellSize,
  });

  Offset toCanvas(VisualPosition position) {
    return Offset(
      origin.dx + cellSize.width * position.x,
      origin.dy + cellSize.height * position.y,
    );
  }
}

abstract class Drawable {
  const Drawable();

  void paint(DrawingContext context, Offset offset);
}

class SolidDrawable extends Drawable {
  final Color color;

  const SolidDrawable(this.color);

  @override
  void paint(DrawingContext context, Offset offset) {
    final paint = Paint()
      ..isAntiAlias = false
      ..color = color;
    context.canvas.drawRect(offset & context.cellSize, paint);
  }
}

class SpriteDrawable extends Drawable {
  final Sprite sprite;

  const SpriteDrawable(this.sprite);

  @override
  void paint(DrawingContext context, Offset offset) {
    sprite.paint(context.canvas, offset & context.cellSize);
  }
}

class CompositeDrawable extends Drawable {
  final List<Drawable> drawables;

  const CompositeDrawable(this.drawables);

  @override
  void paint(DrawingContext context, Offset offset) {
    for (var drawable in drawables) {
      drawable.paint(context, offset);
    }
  }
}

class TransformDrawable extends Drawable {
  final Matrix4 matrix;
  final Drawable drawable;

  const TransformDrawable(this.matrix, this.drawable);

  factory TransformDrawable.rst({
    double rotation = 0.0,
    double scale = 1.0,
    double anchorX = 0.0,
    double anchorY = 0.0,
    double dx = 0.0,
    double dy = 0.0,
    required Drawable drawable,
  }) {
    final transform = RSTransform.fromComponents(
      rotation: rotation,
      scale: scale,
      anchorX: anchorX,
      anchorY: anchorY,
      translateX: dx,
      translateY: dy,
    );
    return TransformDrawable(
      Matrix4(
        transform.scos, transform.ssin, 0, 0, //
        -transform.ssin, transform.scos, 0, 0, //
        0, 0, 0, 0, //
        transform.tx, transform.ty, 0, 1, //
      ),
      drawable,
    );
  }

  @override
  void paint(DrawingContext context, Offset offset) {
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(context.cellSize.width, context.cellSize.height);
    canvas.transform(matrix.storage);
    canvas.scale(1 / context.cellSize.width, 1 / context.cellSize.height);
    drawable.paint(context, Offset.zero);
    canvas.restore();
  }
}

class DrawingElement {
  final Drawable drawable;
  final VisualPosition position;
  final double? opacity;

  const DrawingElement({
    required this.drawable,
    required this.position,
    this.opacity,
  });

  factory DrawingElement.fill(Position position, Color color) {
    return DrawingElement(
      drawable: SolidDrawable(color),
      position: VisualPosition.from(position),
    );
  }

  void paint(DrawingContext context) {
    // TODO: Rotation and opacity.
    drawable.paint(context, context.toCanvas(position));
  }

  DrawingElement operator *(double operand) {
    return DrawingElement(
      drawable: drawable,
      position: position,
      opacity: (opacity ?? 1.0) * operand,
    );
  }

  static DrawingElement? lerp(DrawingElement? a, DrawingElement? b, double t) {
    if (b == null) {
      if (a == null) {
        return null;
      } else {
        return a * (1.0 - t);
      }
    } else {
      if (a == null) {
        return b * t;
      } else {
        return DrawingElement(
          drawable: a.drawable, // TODO: Crossfade drawables.
          position: VisualPosition.lerp(a.position, b.position, t)!,
          opacity: lerpDouble(a.opacity, b.opacity, t),
        );
      }
    }
  }
}

class Drawing {
  final List<DrawingElement> background;
  final LinkedHashMap<Object, DrawingElement> elements;
  final List<DrawingElement> foreground;

  Drawing()
      : background = [],
        elements = LinkedHashMap(),
        foreground = [];

  Drawing._(this.background, this.elements, this.foreground);

  void addBackground(DrawingElement element) {
    background.add(element);
  }

  void add(Object key, DrawingElement element) {
    elements[key] = element;
  }

  void addForeground(DrawingElement element) {
    foreground.add(element);
  }

  void paint(DrawingContext context) {
    for (var element
        in background.followedBy(elements.values).followedBy(foreground)) {
      element.paint(context);
    }
  }

  Drawing operator *(double operand) {
    return Drawing._(
      background.map((value) => value * operand).toList(),
      LinkedHashMap.fromEntries(elements.entries
          .map((MapEntry e) => MapEntry(e.key, e.value * operand))),
      foreground.map((value) => value * operand).toList(),
    );
  }

  static Drawing? lerp(Drawing? a, Drawing? b, double t) {
    if (b == null) {
      if (a == null) {
        return null;
      } else {
        return a * (1.0 - t);
      }
    } else {
      if (a == null) {
        return b * t;
      } else {
        final keys =
            LinkedHashSet.from(a.elements.keys.followedBy(b.elements.keys));
        final LinkedHashMap<Object, DrawingElement> elements = LinkedHashMap();
        for (var key in keys) {
          DrawingElement? element =
              DrawingElement.lerp(a.elements[key], b.elements[key], t);
          if (element != null) {
            elements[key] = element;
          }
        }
        // TODO: Interpolate background and foreground.
        return Drawing._(b.background, elements, b.foreground);
      }
    }
  }
}

class DrawingFrameTween extends Tween<Drawing?> {
  DrawingFrameTween({super.begin, super.end});

  @override
  Drawing? lerp(double t) => Drawing.lerp(begin, end, t);
}
