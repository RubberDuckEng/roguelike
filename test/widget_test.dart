// import 'dart:math';
// import 'package:test/test.dart';

// import 'package:roguelike/model.dart';
// import 'package:roguelike/geometry.dart';

void main() {
  // test('hasPathBetween smoke test', () {
  //   final passable = Block(const [
  //     [Cell.empty(), Cell.empty(), Cell.empty()]
  //   ], enter: const Position(0, 0), exit: const Position(0, 2));

  //   expect(passable.hasPathBetween(const Position(0, 0), const Position(0, 0)),
  //       isTrue);

  //   expect(passable.hasPathBetween(const Position(0, 0), const Position(2, 0)),
  //       isTrue);

  //   final impassible = Block(
  //     const [
  //       [Cell.empty(), Cell.wall(), Cell.empty()]
  //     ],
  //     enter: const Position(0, 0),
  //     exit: const Position(0, 2),
  //   );
  //   expect(
  //       impassible.hasPathBetween(const Position(0, 0), const Position(2, 0)),
  //       isFalse);

  //   final ontoWall = Block(
  //     const [
  //       [Cell.empty(), Cell.empty(), Cell.wall()]
  //     ],
  //     enter: const Position(0, 0),
  //     exit: const Position(0, 2),
  //   );
  //   expect(ontoWall.hasPathBetween(const Position(0, 0), const Position(2, 0)),
  //       isFalse);

  //   final fromWall = Block(
  //     const [
  //       [Cell.wall(), Cell.empty(), Cell.empty()]
  //     ],
  //     enter: const Position(0, 0),
  //     exit: const Position(2, 0),
  //   );
  //   expect(fromWall.hasPathBetween(const Position(0, 0), const Position(2, 0)),
  //       isFalse);
  // });

  // test('cellAt outOfBounds', () {
  //   final level = Block(
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

  // test('MazeLevelGenerator smoketest', () {
  //   final generator = ChunkGenerator(
  //     size: const ISize(10, 10),
  //     start: const Position(0, 0),
  //     end: const Position(9, 9),
  //     random: Random(0),
  //   );
  //   generator.addManyWalls(10);
  //   var level = generator.level;

  //   // FIXME: Where does this belong?
  //   int passableCellCount(Block level) {
  //     return level.allPositions.fold(0,
  //         (total, position) => level.isPassable(position) ? total + 1 : total);
  //   }

  //   expect(passableCellCount(level), 90);
  // });

  // test('MazeLevelGenerator fillUnreachableCells', () {
  //   final generator = ChunkGenerator(
  //     size: const ISize(3, 3),
  //     start: const Position(0, 0),
  //     end: const Position(1, 0),
  //     random: Random(0),
  //   );
  //   generator.level.setCell(const Position(0, 1), const Cell.wall());
  //   generator.level.setCell(const Position(1, 2), const Cell.wall());

  //   expect(generator.level.isPassable(const Position(0, 2)), isTrue);
  //   generator.fillUnreachableCells();
  //   expect(generator.level.isPassable(const Position(0, 2)), isFalse);
  // });
}
