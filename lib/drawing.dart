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

  DrawingElement({
    required this.drawable,
    required this.position,
    this.rotation,
    this.opacity,
  });

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
  final Map<Object, DrawingElement> elements;

  Drawing() : elements = {};

  Drawing._(this.elements);

  void add(Object key, DrawingElement element) {
    elements[key] = element;
  }

  void paint(DrawingContext context) {
    for (var element in elements.values) {
      element.paint(context);
    }
  }

  Drawing operator *(double operand) {
    return Drawing._(
        elements.map((key, value) => MapEntry(key, value * operand)));
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
        final keys = Set.from(a.elements.keys.followedBy(b.elements.keys));
        final Map<Object, DrawingElement> elements = {};
        for (var key in keys) {
          DrawingElement? element =
              DrawingElement.lerp(a.elements[key], b.elements[key], t);
          if (element != null) {
            elements[key] = element;
          }
        }
        return Drawing._(elements);
      }
    }
  }
}

class DrawingFrameTween extends Tween<Drawing?> {
  DrawingFrameTween({super.begin, super.end});

  @override
  Drawing? lerp(double t) => Drawing.lerp(begin, end, t);
}
