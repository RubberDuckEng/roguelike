import 'package:flutter/material.dart';

import 'model.dart';
import 'geometry.dart';
import 'sprite.dart';

class CellPainter {
  final Canvas canvas;
  final Rect targetRect;
  final Size cellSize;

  CellPainter(this.canvas, this.targetRect)
      : cellSize = Size(targetRect.width / kChunkSize.width,
            targetRect.height / kChunkSize.width);

  Rect rectForPosition(GridPosition position) {
    return Rect.fromLTWH(
      targetRect.left + position.x * cellSize.width,
      targetRect.top + position.y * cellSize.height,
      cellSize.width,
      cellSize.height,
    );
  }

  void fillCell(GridPosition position, Color color) {
    final paint = Paint();
    paint.isAntiAlias = false;
    paint.color = color;
    canvas.drawRect(rectForPosition(position), paint);
  }

  void paintSprite(Sprite sprite, GridPosition position) {
    sprite.paint(canvas, rectForPosition(position));
  }
}

class ChunkPainter {
  final CellPainter painter;
  final Chunk chunk;

  ChunkPainter(this.painter, this.chunk);

  void paintBackground() {
    // allPositions does not guarentee order.
    for (var position in chunk.allGridPositions) {
      var color = chunk.isPassableLocal(position)
          ? Colors.brown.shade300
          : Colors.brown.shade600;
      painter.fillCell(position, color);
    }
  }

  void paintMob(Mob mob) {
    painter.paintSprite(mob.sprite, chunk.toLocal(mob.location));
  }

  void paintItems() {
    for (var position in chunk.allGridPositions) {
      var item = chunk.itemAtLocal(position);
      if (item != null) {
        painter.paintSprite(item.sprite, position);
      }
    }
  }

  void paintFogOfWar() {
    for (var position in chunk.allGridPositions) {
      var isRevealed = chunk.isRevealedLocal(position);
      if (!isRevealed) {
        painter.fillCell(position, Colors.black);
      } else {
        // Don't paint fog over walls to avoid changing their color.
        var isWall = chunk.getCellLocal(position).type == CellType.wall;
        if (!isWall) {
          var isLit = chunk.isLitLocal(position);
          if (!isLit) {
            painter.fillCell(position, Colors.black38);
          }
        }
      }
    }
  }

  void paint(GameState gameState) {
    paintBackground();
    paintItems();
    for (var mob in chunk.enemies) {
      // Only paint mobs outside the fog of war.
      if (chunk.isLit(mob.location)) {
        paintMob(mob);
      }
    }
    paintMob(gameState.player);
    paintFogOfWar();
  }
}
