import 'dart:collection';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/game/components/game_map.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/cover.dart';
import 'package:topsoldier/rules/movement.dart';

/// assets/maps/frontline.tmx를 그대로 읽어서 decisions 11장 조건을 검사한다.
void main() {
  final map = GameMap.fromTmx(
    File('assets/maps/frontline.tmx').readAsStringSync(),
  );
  final w = map.width, h = map.height;
  const cell = GameMap.gridSize;

  Box rot(Box b) => (
    left: w - b.right,
    top: h - b.bottom,
    right: w - b.left,
    bottom: h - b.top,
  );
  String other(String team) => team == 'A' ? 'B' : 'A';

  test('size is a multiple of the 70px grid', () {
    expect((w, h), (1610, 2590));
  });

  test('180° rotational symmetry for every wall, crate, spawn and base', () {
    for (final list in [map.highWalls, map.lowCrates]) {
      for (final b in list) {
        expect(list, contains(rot(b)), reason: '$b has no rotated pair');
      }
    }
    for (final s in map.spawns) {
      expect(
        map.spawns,
        contains((pos: (x: w - s.pos.x, y: h - s.pos.y), team: other(s.team))),
        reason: '$s has no rotated pair',
      );
    }
    for (final b in map.bases) {
      expect(map.bases, contains((area: rot(b.area), team: other(b.team))));
    }
  });

  test('walls and crates sit on the 70px grid, everything inside the map', () {
    for (final b in [
      ...map.highWalls,
      ...map.lowCrates,
      for (final b in map.bases) b.area,
    ]) {
      for (final v in [b.left, b.top, b.right, b.bottom]) {
        expect(v % cell, 0, reason: '$b is off the grid');
      }
      expect(
        b.left >= 0 && b.top >= 0 && b.right <= w && b.bottom <= h,
        isTrue,
        reason: '$b is outside the map',
      );
    }
    for (final s in map.spawns) {
      expect(s.pos.x > 0 && s.pos.x < w && s.pos.y > 0 && s.pos.y < h, isTrue);
    }
  });

  test(
    '3 spawns per team, none touching a wall or crate, each inside its base',
    () {
      for (final team in ['A', 'B']) {
        final spawns = map.spawnsOf(team);
        expect(spawns, hasLength(3));
        final base = map.bases.singleWhere((b) => b.team == team).area;
        for (final s in spawns) {
          for (final b in [...map.highWalls, ...map.lowCrates]) {
            expect(
              circleOverlapsBox(s, playerRadius, b),
              isFalse,
              reason: '$team spawn $s overlaps $b',
            );
          }
          expect(pointInBox(s, base), isTrue, reason: '$team spawn $s');
        }
      }
    },
  );

  // 70px 칸 단위. 높은 벽이 걸친 칸만 막힘(낮은 상자는 점프로 넘으니 통과).
  final cols = (w / cell).round(), rows = (h / cell).round();
  Box cellBox(int c, int r) => (
    left: c * cell,
    top: r * cell,
    right: (c + 1) * cell,
    bottom: (r + 1) * cell,
  );
  bool overlaps(Box a, Box b) =>
      a.left < b.right &&
      b.left < a.right &&
      a.top < b.bottom &&
      b.top < a.bottom;
  final blocked = [
    for (var r = 0; r < rows; r++)
      [
        for (var c = 0; c < cols; c++)
          map.highWalls.any((wall) => overlaps(cellBox(c, r), wall)),
      ],
  ];

  test(
    'every spawn can walk to the enemy base (BFS, only high walls block)',
    () {
      for (final s in map.spawns) {
        final start = (s.pos.x ~/ cell, s.pos.y ~/ cell);
        final seen = {start};
        final queue = Queue.of([start]);
        while (queue.isNotEmpty) {
          final (c, r) = queue.removeFirst();
          for (final (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
            final n = (c + dc, r + dr);
            if (n.$1 < 0 || n.$2 < 0 || n.$1 >= cols || n.$2 >= rows) continue;
            if (blocked[n.$2][n.$1] || !seen.add(n)) continue;
            queue.add(n);
          }
        }
        final enemyBase = map.bases
            .singleWhere((b) => b.team == other(s.team))
            .area;
        expect(
          seen.any((c) => overlaps(cellBox(c.$1, c.$2), enemyBase)),
          isTrue,
          reason: '${s.team} spawn ${s.pos} cannot reach the enemy base',
        );
      }
    },
  );

  test('no spawn is visible in a straight line from outside its own base', () {
    const step = 35.0; // 반 칸 간격 샘플
    for (final s in map.spawns) {
      final base = map.bases.singleWhere((b) => b.team == s.team).area;
      final seenFrom = <Vec>[];
      for (var y = step / 2; y < h; y += step) {
        for (var x = step / 2; x < w; x += step) {
          final p = (x: x, y: y);
          if (pointInBox(p, base) || blocked[y ~/ cell][x ~/ cell]) continue;
          if (!lineBlockedByHighWall(p, s.pos, map.highWalls)) seenFrom.add(p);
        }
      }
      expect(
        seenFrom,
        isEmpty,
        reason: '${s.team} spawn ${s.pos} visible from ${seenFrom.take(3)}',
      );
    }
  });
}
