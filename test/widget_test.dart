import 'package:test/test.dart';

import 'package:roguelike/geometry.dart';

void main() {
  // test('cellAt outOfBounds', () {
  //   final level = Chunk(
  //     const [
  //       [Cell.empty(), Cell.wall()]
  //     ],
  //     enter: const Position(0, 0),
  //     exit: const Position(0, 1),
  //   );
  //   expect(level.getCell(const Position(0, 0)).type, equals(CellType.empty));
  //   expect(level.getCell(const Position(1, 0)).type, equals(CellType.wall));
  //   expect(
  //       level.getCell(const Position(0, 1)).type, equals(CellType.outOfBounds));
  //   expect(level.getCell(const Position(-1, 0)).type,
  //       equals(CellType.outOfBounds));
  //   expect(level.getCell(const Position(0, -1)).type,
  //       equals(CellType.outOfBounds));
  // });

  test('Position.positionsInNearbyGrid', () {
    var positions = const Position(0, 0).positionsInNearbyGrid(1, 1).toList();
    expect(positions.length, 9);

    var expectedPositions = [
      const Position(-1, -1),
      const Position(0, -1),
      const Position(1, -1),
      const Position(-1, 0),
      const Position(0, 0),
      const Position(1, 0),
      const Position(-1, 1),
      const Position(0, 1),
      const Position(1, 1),
    ];
    expect(positions, equals(expectedPositions));
  });
}
