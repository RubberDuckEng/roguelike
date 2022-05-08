import 'dart:collection';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'geometry.dart';

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

abstract class Drawable {
  const Drawable();

  void paint(Canvas canvas, Rect rect);
}

class SolidColor extends Drawable {
  final Color color;

  const SolidColor(this.color);

  @override
  void paint(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..isAntiAlias = false
      ..color = color;
    canvas.drawRect(rect, paint);
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

  Rect toCellRect(VisualPosition position) => toCanvas(position) & cellSize;

  void paintDrawable(Drawable drawable, VisualPosition position) {
    drawable.paint(canvas, toCellRect(position));
  }
}

class DrawingElement {
  final Drawable drawable;
  final VisualPosition position;
  final double? rotation;
  final double? opacity;

  const DrawingElement({
    required this.drawable,
    required this.position,
    this.rotation,
    this.opacity,
  });

  factory DrawingElement.fill(Position position, Color color) {
    return DrawingElement(
      drawable: SolidColor(color),
      position: VisualPosition.from(position),
    );
  }

  void paint(DrawingContext context) {
    // TODO: Rotation and opacity.
    context.paintDrawable(drawable, position);
  }

  DrawingElement operator *(double operand) {
    return DrawingElement(
      drawable: drawable,
      position: position,
      rotation: rotation,
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
          rotation:
              lerpDouble(a.rotation, b.rotation, t), // TODO: Needs quaterions.
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
