import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

import 'geometry.dart';
import 'sprite.dart';

class DrawingContext {
  final Canvas canvas;
  final Offset origin;
  final Size cellSize;
  final Duration elapsed;

  DrawingContext({
    required this.canvas,
    required this.origin,
    required this.cellSize,
    required this.elapsed,
  });

  Offset toCanvas(Offset position) {
    return Offset(
      origin.dx + cellSize.width * position.dx,
      origin.dy + cellSize.height * position.dy,
    );
  }
}

abstract class Drawable {
  const Drawable();

  void paint(DrawingContext context, Offset offset);

  Drawable operator *(double operand) =>
      TransformDrawable.rst(scale: operand, drawable: this);

  Drawable operator +(Offset offset) =>
      TransformDrawable.rst(dx: offset.dx, dy: offset.dy, drawable: this);
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
    final matrix = Matrix4.identity()
      ..translate(0.5, 0.5)
      ..multiply(Matrix4(
        transform.scos, transform.ssin, 0, 0, //
        -transform.ssin, transform.scos, 0, 0, //
        0, 0, 0, 0, //
        transform.tx, transform.ty, 0, 1, //
      ))
      ..translate(-0.5, -0.5);
    return TransformDrawable(
      matrix,
      drawable,
    );
  }

  @override
  void paint(DrawingContext context, Offset offset) {
    final canvas = context.canvas;
    final cellSize = context.cellSize;
    final transform = Matrix4.identity()
      ..translate(offset.dx, offset.dy)
      ..scale(cellSize.width, cellSize.height)
      ..multiply(matrix)
      ..scale(1.0 / cellSize.width, 1.0 / cellSize.height);
    canvas.save();
    canvas.transform(transform.storage);
    drawable.paint(context, Offset.zero);
    canvas.restore();
  }
}

abstract class Orbit {
  const Orbit();

  Offset getOffset(DrawingContext context);
}

class CircularOrbit extends Orbit {
  final double radius;
  final Duration period;

  const CircularOrbit({required this.radius, required this.period});

  @override
  Offset getOffset(DrawingContext context) {
    final angle =
        2 * pi * (context.elapsed.inMicroseconds / period.inMicroseconds);
    final cellSize = context.cellSize;
    return Offset(
      radius * cos(angle) * cellSize.width,
      radius * sin(angle) * cellSize.height,
    );
  }
}

class OrbitAnimation extends Drawable {
  final Drawable drawable;
  final Orbit orbit;

  const OrbitAnimation(this.orbit, this.drawable);

  @override
  void paint(DrawingContext context, Offset offset) {
    drawable.paint(context, offset + orbit.getOffset(context));
  }
}

class _DrawingElement {
  final Drawable drawable;
  final Offset position;

  const _DrawingElement(this.drawable, this.position);

  void paint(DrawingContext context) {
    drawable.paint(context, context.toCanvas(position));
  }

  _DrawingElement operator *(double operand) {
    return _DrawingElement(
      drawable * operand,
      position,
    );
  }

  static _DrawingElement? lerp(
      _DrawingElement? a, _DrawingElement? b, double t) {
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
        return _DrawingElement(
          b.drawable, // TODO: Crossfade drawables.
          Offset.lerp(a.position, b.position, t)!,
        );
      }
    }
  }
}

class Drawing {
  final List<_DrawingElement> background;
  final LinkedHashMap<Object, _DrawingElement> elements;
  final List<_DrawingElement> foreground;

  Drawing()
      : background = [],
        elements = LinkedHashMap(),
        foreground = [];

  Drawing._(this.background, this.elements, this.foreground);

  void addBackground(Drawable drawable, Position position) {
    background.add(_DrawingElement(drawable, position.toOffset()));
  }

  void add(Object key, Drawable drawable, Position position) {
    elements[key] = _DrawingElement(drawable, position.toOffset());
  }

  void addForeground(Drawable drawable, Position position) {
    foreground.add(_DrawingElement(drawable, position.toOffset()));
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
        final LinkedHashMap<Object, _DrawingElement> elements = LinkedHashMap();
        for (var key in keys) {
          _DrawingElement? element =
              _DrawingElement.lerp(a.elements[key], b.elements[key], t);
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

class DrawingTween extends Tween<Drawing?> {
  DrawingTween({super.begin, super.end});

  @override
  Drawing? lerp(double t) => Drawing.lerp(begin, end, t);
}
