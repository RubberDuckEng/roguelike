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

class Drawing {
  final Drawable drawable;
  final VisualPosition position;
  final double? rotation;
  final double? opacity;

  Drawing({
    required this.drawable,
    required this.position,
    this.rotation,
    this.opacity,
  });

  void paint(Canvas canvas, Offset offset, Size cellSize) {
    drawable.paint(canvas, offset & cellSize);
  }

  Drawing operator *(double operand) {
    return Drawing(
      drawable: drawable,
      position: position,
      rotation: rotation,
      opacity: (opacity ?? 1.0) * operand,
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
        return Drawing(
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

class DrawingFrame {
  final Map<Object, Drawing> _drawings;

  DrawingFrame() : _drawings = {};

  DrawingFrame._(this._drawings);

  void add(Object key, Drawing drawing) {
    _drawings[key] = drawing;
  }

  DrawingFrame operator *(double operand) {
    return DrawingFrame._(
        _drawings.map((key, value) => MapEntry(key, value * operand)));
  }

  static DrawingFrame? lerp(DrawingFrame? a, DrawingFrame? b, double t) {
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
        final keys = Set.from(a._drawings.keys.followedBy(b._drawings.keys));
        final Map<Object, Drawing> drawings = {};
        for (var key in keys) {
          Drawing? drawing =
              Drawing.lerp(a._drawings[key], b._drawings[key], t);
          if (drawing != null) {
            drawings[key] = drawing;
          }
        }
        return DrawingFrame._(drawings);
      }
    }
  }
}

class DrawingFrameTween extends Tween<DrawingFrame?> {
  DrawingFrameTween({super.begin, super.end});

  @override
  DrawingFrame? lerp(double t) => DrawingFrame.lerp(begin, end, t);
}
