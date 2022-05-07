import 'package:flutter/material.dart';

import 'model.dart';
import 'geometry.dart';
import 'drawing.dart';

// void paintCarriedBlock(
//     GridPosition position, Color color, Direction direction) {
//   final paint = Paint();
//   paint.isAntiAlias = false;
//   paint.color = color;
//   // FIXME: Use direction?
//   var cellRect = rectForPosition(position);
//   var blockRect = Rect.fromCenter(
//       center: cellRect.center - Offset(0, cellRect.height / 2),
//       width: cellRect.width / 4,
//       height: cellRect.height / 4);
//   canvas.drawRect(blockRect, paint);
// }

class ChunkPainter {
  final DrawingContext context;
  final Chunk chunk;

  ChunkPainter(this.context, this.chunk);

  void fillCell(GridPosition position, Color color) {
    // TODO: This rect calcuation is overly complicated because we should be
    // doing this work in the drawing phase rather than the painting phase.
    final rect =
        context.toCellRect(VisualPosition.from(chunk.toGlobal(position)));
    final paint = Paint();
    paint.isAntiAlias = false;
    paint.color = color;
    context.canvas.drawRect(rect, paint);
  }

  void paintBackground() {
    // allPositions does not guarentee order.
    for (var position in chunk.allGridPositions) {
      var color = chunk.isPassableLocal(position)
          ? Colors.brown.shade300
          : Colors.brown.shade600;
      fillCell(position, color);
    }
  }

  void paintForeground() {
    for (var position in chunk.allGridPositions) {
      var isRevealed = chunk.isRevealedLocal(position);
      if (!isRevealed) {
        fillCell(position, Colors.black);
      } else {
        // Don't paint fog over walls to avoid changing their color.
        var isWall = chunk.getCellLocal(position).type == CellType.wall;
        if (!isWall) {
          var isLit = chunk.isLitLocal(position);
          if (!isLit) {
            fillCell(position, Colors.black38);
          }
        }
      }
    }
  }
}
