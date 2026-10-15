import 'dart:collection';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/game/components/game_map.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/cover.dart';
import 'package:topsoldier/rules/movement.dart';

import 'map_rules.dart';

typedef Cell = (int, int);

/// 칸 단위 4방향 BFS. [blocked]인 칸은 못 지나간다. 시작 칸에서 각 칸까지 걸음 수.
Map<Cell, int> bfs(GameMap map, Cell start, bool Function(Cell) blocked) {
  const cell = GameMap.gridSize;
  final cols = (map.width / cell).round(), rows = (map.height / cell).round();
  final dist = {start: 0};
  final queue = Queue.of([start]);
  while (queue.isNotEmpty) {
    final (c, r) = queue.removeFirst();
    for (final (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final n = (c + dc, r + dr);
      if (n.$1 < 0 || n.$2 < 0 || n.$1 >= cols || n.$2 >= rows) continue;
      if (blocked(n) || dist.containsKey(n)) continue;
      dist[n] = dist[(c, r)]! + 1;
      queue.add(n);
    }
  }
  return dist;
}

bool inBox(Cell c, Box b) {
  const cell = GameMap.gridSize;
  final cx = (c.$1 + 0.5) * cell, cy = (c.$2 + 0.5) * cell;
  return cx > b.left && cx < b.right && cy > b.top && cy < b.bottom;
}

Cell cellOf(Vec p) => (p.x ~/ GameMap.gridSize, p.y ~/ GameMap.gridSize);

/// 스폰에서 상대 스폰까지 BFS 길이(6개 스폰 × 상대 스폰 3개 평균).
double averagePathLength(GameMap map, bool Function(Cell) blocked) {
  var total = 0, n = 0;
  for (final s in map.spawns) {
    final dist = bfs(map, cellOf(s.pos), blocked);
    for (final e in map.spawns.where((e) => e.team != s.team)) {
      total += dist[cellOf(e.pos)]!;
      n++;
    }
  }
  return total / n;
}

/// 1대1 전용 맵 duel(decisions 11장).
void main() {
  // 모든 PvP 맵이 지키는 규칙(크기 17 × 17칸 = 1190px 포함).
  mapRulesTests('duel', 1190);

  final map = GameMap.fromTmx(File('assets/maps/duel.tmx').readAsStringSync());
  final outpost = GameMap.fromTmx(
    File('assets/maps/outpost.tmx').readAsStringSync(),
  );
  bool wallCell(GameMap m, Cell c) => m.highWalls.any((b) => inBox(c, b));
  bool wallOrCrate(GameMap m, Cell c) =>
      wallCell(m, c) || m.lowCrates.any((b) => inBox(c, b));

  test('minimap reach fills the circle (579 px of a 595 px half-map)', () {
    expect(map.reach, closeTo(579, 1));
  });

  test('every spawn walks to the cell beside the centre pillar in ≤ 4 s', () {
    // 가운데 기둥은 8열 7~9행. 그 옆 칸 (7,8)·(9,8) 중 가까운 곳까지.
    final times = <double>[];
    for (final s in map.spawnsOf('A')) {
      final dist = bfs(map, cellOf(s), (c) => wallCell(map, c));
      final steps = [
        dist[(7, 8)]!,
        dist[(9, 8)]!,
      ].reduce((a, b) => a < b ? a : b);
      final seconds = steps * GameMap.gridSize / walkSpeed;
      times.add(seconds);
      expect(seconds, lessThanOrEqualTo(4), reason: '$s: $steps steps');
    }
    // 재서 본 값(PM 계산 11·12·11칸 = 3.5·3.8·3.5초).
    // ignore: avoid_print
    print(
      'spawn → pillar side seconds: ${times.map((t) => t.toStringAsFixed(2))}',
    );
  });

  test('spawn to the enemy spawn is ≥ 40% shorter than outpost', () {
    final duel = averagePathLength(map, (c) => wallCell(map, c));
    final far = averagePathLength(outpost, (c) => wallCell(outpost, c));
    // ignore: avoid_print
    print('average path: duel $duel, outpost $far cells');
    expect(duel, lessThanOrEqualTo(far * 0.6));
  });

  test('crates count as blocked (bots do not jump): spawns still connect', () {
    for (final s in map.spawns) {
      final dist = bfs(map, cellOf(s.pos), (c) => wallOrCrate(map, c));
      for (final e in map.spawns.where((e) => e.team != s.team)) {
        expect(dist, contains(cellOf(e.pos)), reason: '$s cannot reach $e');
      }
    }
    final lengths = [
      for (final s in map.spawnsOf('A'))
        bfs(map, cellOf(s), (c) => wallOrCrate(map, c))[cellOf(
          map.spawnsOf('B').first,
        )]!,
    ];
    // ignore: avoid_print
    print('A spawns → first B spawn, crates blocked: $lengths cells');
  });

  test('at least 60% of walkable floor cells touch a crate (8 directions)', () {
    final cols = (map.width / GameMap.gridSize).round();
    final floor = <Cell>[
      for (var r = 0; r < cols; r++)
        for (var c = 0; c < cols; c++)
          if (!wallCell(map, (c, r)) &&
              !map.lowCrates.any((b) => inBox((c, r), b)))
            (c, r),
    ];
    final touching = floor.where((f) {
      for (var dc = -1; dc <= 1; dc++) {
        for (var dr = -1; dr <= 1; dr++) {
          if ((dc, dr) == (0, 0)) continue;
          final n = (f.$1 + dc, f.$2 + dr);
          if (map.lowCrates.any((b) => inBox(n, b))) return true;
        }
      }
      return false;
    }).length;
    // ignore: avoid_print
    print('floor cells touching a crate: $touching / ${floor.length}');
    expect(touching / floor.length, greaterThanOrEqualTo(0.6));
  });

  test('from the right gap crate (12,12) you can look at the pillar side '
      '(9,8) over the high walls', () {
    const cell = GameMap.gridSize;
    const from = (x: 12.5 * cell, y: 12.5 * cell);
    const to = (x: 9.5 * cell, y: 8.5 * cell);
    expect(lineBlockedByHighWall(from, to, map.highWalls), isFalse);
  });
}
