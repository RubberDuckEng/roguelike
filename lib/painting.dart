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
