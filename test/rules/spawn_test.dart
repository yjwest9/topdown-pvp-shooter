import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/movement.dart';
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

  group('2v2 spawns', () {
    final spawns = <Vec>[
      (x: 0.0, y: 0.0),
      (x: 100.0, y: 0.0),
      (x: 200.0, y: 0.0),
    ];
    // 적은 왼쪽 위쪽에 있다: 가장 가까운 적과의 거리는 오른쪽 스폰일수록 멀다.
    final enemies = <Vec>[(x: -50.0, y: 0.0), (x: -20.0, y: 40.0)];

    test(
      'ranked by the nearest enemy, farthest first (ties keep the order)',
      () {
        expect(spawnsByDistance(spawns, enemies), [
          spawns[2],
          spawns[1],
          spawns[0],
        ]);
        expect(spawnsByDistance(spawns, const []), spawns);
        // 가장 가까운 적 기준: 한 명이 멀어도 다른 한 명이 가까우면 가까운 쪽으로 친다.
        final near = <Vec>[(x: 200.0, y: 0.0), (x: -1000.0, y: 0.0)];
        expect(spawnsByDistance(spawns, near).first, spawns[0]);
      },
    );

    test(
      'start: allies (by uid order) take different spawns, farthest first',
      () {
        final a = startSpawn(spawns, enemies, allyIndex: 0);
        final b = startSpawn(spawns, enemies, allyIndex: 1);
        expect(a, spawns[2]);
        expect(b, spawns[1]);
        expect(a == b, false);
        // 팀 스폰보다 사람이 많으면 한 바퀴 돈다.
        expect(startSpawn(spawns, enemies, allyIndex: 3), spawns[2]);
      },
    );

    test('respawn: skip a spawn where an ally already stands', () {
      // 가장 먼 스폰(200)에 아군이 서 있으면 다음으로 먼 곳(100).
      final ally = <Vec>[(x: 210.0, y: 10.0)];
      expect(respawnSpawn(spawns, enemies, ally), spawns[1]);
      // 아군이 없으면 가장 먼 곳.
      expect(respawnSpawn(spawns, enemies, const []), spawns[2]);
      // 모두 막혔으면 가장 먼 곳(어쩔 수 없다).
      final all = <Vec>[for (final s in spawns) (x: s.x + 5, y: s.y)];
      expect(respawnSpawn(spawns, enemies, all), spawns[2]);
    });

    test('farthestSpawn (1v1) is unchanged', () {
      expect(farthestSpawn(spawns, enemies), spawns[2]);
      expect(farthestSpawn(spawns, const []), spawns[0]);
    });
  });
}
