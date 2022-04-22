import 'package:test/test.dart';

import 'package:roguelike/model.dart';

void main() {
  test('hasPathBetween smoke test', () {
    final passable = Level(const [
      [Cell.empty(), Cell.empty(), Cell.empty()]
    ]);

    expect(passable.hasPathBetween(const Position(0, 0), const Position(0, 0)),
        isTrue);

    expect(passable.hasPathBetween(const Position(0, 0), const Position(2, 0)),
        isTrue);

    final impassible = Level(const [
      [Cell.empty(), Cell.wall(), Cell.empty()]
    ]);
    expect(
        impassible.hasPathBetween(const Position(0, 0), const Position(2, 0)),
        isFalse);

    final ontoWall = Level(const [
      [Cell.empty(), Cell.empty(), Cell.wall()]
    ]);
    expect(ontoWall.hasPathBetween(const Position(0, 0), const Position(2, 0)),
        isFalse);
  });

  test('cellAt outOfBounds', () {
    final level = Level(const [
      [Cell.empty(), Cell.wall()]
    ]);
    expect(level.getCell(const Position(0, 0)).type, equals(CellType.empty));
    expect(level.getCell(const Position(1, 0)).type, equals(CellType.wall));
    expect(
        level.getCell(const Position(0, 1)).type, equals(CellType.outOfBounds));
    expect(level.getCell(const Position(-1, 0)).type,
        equals(CellType.outOfBounds));
    expect(level.getCell(const Position(0, -1)).type,
        equals(CellType.outOfBounds));
  });

  test('MazeLevelGenerator', () {
    final generator = MazeLevelGenerator(
      size: const ISize(10, 10),
      start: const Position(0, 0),
      end: const Position(9, 9),
      seed: 0,
    );
    generator.addManyWalls(80);
    expect(generator.level.toString(), '???');
  });
}
