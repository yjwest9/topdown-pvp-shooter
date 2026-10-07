import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/spawn.dart';

void main() {
  const spawns = [
    (x: 100.0, y: 900.0),
    (x: 500.0, y: 900.0),
    (x: 900.0, y: 900.0),
  ];

  test('picks the spawn farthest from the enemy', () {
    expect(farthestSpawn(spawns, [(x: 150.0, y: 700.0)]), spawns[2]);
    expect(farthestSpawn(spawns, [(x: 880.0, y: 700.0)]), spawns[0]);
  });

  test('with several enemies, maximizes distance to the nearest one', () {
    // 양쪽 끝에 적이 있으면 가운데가 가장 안전하다.
    expect(
      farthestSpawn(spawns, [(x: 100.0, y: 850.0), (x: 900.0, y: 850.0)]),
      spawns[1],
    );
  });

  test('no enemy known: first spawn', () {
    expect(farthestSpawn(spawns, const []), spawns[0]);
  });
}
