import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/bot.dart';
import 'package:topsoldier/rules/cover.dart';
import 'package:topsoldier/rules/movement.dart';

CoverBody body(
  double x,
  double y, {
  bool crouching = false,
  bool onCrate = false,
}) => (
  pos: (x: x, y: y),
  crouching: crouching,
  airborne: false,
  onCrate: onCrate,
);

Box cell(int cx, int cy) => (
  left: cx * 70.0,
  top: cy * 70.0,
  right: cx * 70.0 + 70,
  bottom: cy * 70.0 + 70,
);

void main() {
  group('NavGrid', () {
    // 5 × 5칸. 가운데 열(2)이 0~3행 막힘 → 4행으로 돌아가야 한다.
    final grid = NavGrid(
      width: 350,
      height: 350,
      blocks: [for (var y = 0; y < 4; y++) cell(2, y)],
    );

    test('open line: walks straight cell by cell', () {
      final p = grid.path((x: 35, y: 35), (x: 35, y: 315));
      expect(p, [
        (x: 35.0, y: 105.0),
        (x: 35.0, y: 175.0),
        (x: 35.0, y: 245.0),
        (x: 35.0, y: 315.0),
      ]);
    });

    test('goes around a wall, never through a blocked cell', () {
      final p = grid.path((x: 35, y: 35), (x: 315, y: 35));
      expect(p.last, (x: 315.0, y: 35.0));
      expect(p.any((c) => (c.x - 175).abs() < 1 && c.y < 280), isFalse);
      expect(p, contains((x: 175.0, y: 315.0)));
      // 4방향 이동이라 이웃 칸끼리 70px.
      for (var i = 1; i < p.length; i++) {
        final d = (p[i].x - p[i - 1].x).abs() + (p[i].y - p[i - 1].y).abs();
        expect(d, 70);
      }
    });

    test('same cell or unreachable: empty', () {
      expect(grid.path((x: 30, y: 30), (x: 40, y: 40)), isEmpty);
      final walled = NavGrid(width: 210, height: 70, blocks: [cell(1, 0)]);
      expect(walled.path((x: 35, y: 35), (x: 175, y: 35)), isEmpty);
    });

    test('walkable checks the body circle against blocks', () {
      expect(grid.walkable((x: 35, y: 35)), isTrue);
      expect(grid.walkable((x: 175, y: 35)), isFalse);
      // 벽 가장자리에서 반경 안.
      expect(grid.walkable((x: 140 - playerRadius + 2, y: 35)), isFalse);
      expect(grid.walkable((x: -5, y: 35)), isFalse);
    });
  });

  group('aim', () {
    test('average velocity over the predict window', () {
      final history = [
        (t: 0.0, p: (x: 0.0, y: 0.0)),
        (t: 0.5, p: (x: 0.0, y: 0.0)),
        (t: 0.65, p: (x: 30.0, y: 0.0)),
        (t: 1.0, p: (x: 100.0, y: 0.0)),
      ];
      // 0.65~1.0 → 70px / 0.35s = 200px/s (0.35초 이전 샘플은 안 씀).
      final v = averageVelocity(history, window: 0.35);
      expect(v.x, closeTo(200, 1e-9));
      expect(v.y, 0);
      expect(averageVelocity(const [], window: 0.35), (x: 0.0, y: 0.0));
    });

    test('a sudden turn is not seen yet (lags behind)', () {
      // 0.3초 동안 오른쪽, 마지막 0.05초만 위로.
      final history = [
        (t: 0.0, p: (x: 0.0, y: 0.0)),
        (t: 0.3, p: (x: 60.0, y: 0.0)),
        (t: 0.35, p: (x: 60.0, y: -10.0)),
      ];
      final v = averageVelocity(history, window: 0.35);
      expect(v.x, greaterThan(v.y.abs()));
    });

    test('still target: aims straight at it', () {
      expect(
        leadAngle((x: 0, y: 0), (x: 0, y: 300), (x: 0, y: 0)),
        closeTo(pi / 2, 1e-9),
      );
    });

    test('moving target: leads by flight time', () {
      // 750px 거리 → 1초 비행, 오른쪽 100px/s → (100, 750)을 노린다.
      expect(
        leadAngle((x: 0, y: 0), (x: 0, y: 750), (x: 100, y: 0)),
        closeTo(atan2(750, 100), 1e-9),
      );
    });
  });

  group('canSee', () {
    const walls = [(left: 90.0, top: -50.0, right: 110.0, bottom: 50.0)];
    const crates = [(left: 280.0, top: -20.0, right: 320.0, bottom: 20.0)];

    test('in range and nothing between', () {
      expect(
        canSee(
          body(0, 0),
          body(0, 200),
          range: 500,
          highWalls: walls,
          lowCrates: crates,
        ),
        isTrue,
      );
    });

    test('out of range or behind a high wall', () {
      expect(
        canSee(
          body(0, 0),
          body(0, 600),
          range: 500,
          highWalls: walls,
          lowCrates: crates,
        ),
        isFalse,
      );
      expect(
        canSee(
          body(0, 0),
          body(200, 0),
          range: 500,
          highWalls: walls,
          lowCrates: crates,
        ),
        isFalse,
      );
    });

    test('low cover hides both ways', () {
      final hidden = body(345, 0, crouching: true);
      expect(
        canSee(
          body(200, 0),
          hidden,
          range: 500,
          highWalls: const [],
          lowCrates: crates,
        ),
        isFalse,
      );
      expect(
        canSee(
          hidden,
          body(200, 0),
          range: 500,
          highWalls: const [],
          lowCrates: crates,
        ),
        isFalse,
      );
    });
  });

  group('coverSpot', () {
    const crate = (left: 280.0, top: 280.0, right: 350.0, bottom: 350.0);

    test('far side of the crate from the enemy, hides when crouched', () {
      const enemy = (x: 315.0, y: 0.0);
      final spot = coverSpot(
        (x: 315, y: 500),
        enemy,
        const [crate],
        walkable: (_) => true,
      )!;
      expect(spot.y, greaterThan(crate.bottom));
      final hidden = hiddenBehindLowCover(
        body(spot.x, spot.y, crouching: true),
        body(enemy.x, enemy.y),
        const [crate],
      );
      expect(hidden, isTrue);
    });

    test('picks the crate nearest to me, skips far or blocked spots', () {
      const near = (left: 0.0, top: 280.0, right: 70.0, bottom: 350.0);
      const enemy = (x: 200.0, y: 0.0);
      final spot = coverSpot(
        (x: 35, y: 450),
        enemy,
        const [crate, near],
        walkable: (_) => true,
      )!;
      expect(distanceToBox(spot, near), lessThan(lowCoverRange));

      expect(
        coverSpot((x: 35, y: 450), enemy, const [near], walkable: (_) => false),
        isNull,
      );
      expect(
        coverSpot((x: 35, y: 2000), enemy, const [near], walkable: (_) => true),
        isNull,
      );
    });
  });

  test('bot levels get harder in every number', () {
    final e = botLevels[BotDifficulty.easy]!;
    final n = botLevels[BotDifficulty.normal]!;
    final h = botLevels[BotDifficulty.hard]!;
    expect(e.reaction > n.reaction && n.reaction > h.reaction, isTrue);
    expect(e.aimError > n.aimError && n.aimError > h.aimError, isTrue);
    expect(
      e.jumpPerSecond < n.jumpPerSecond && n.jumpPerSecond < h.jumpPerSecond,
      isTrue,
    );
  });
}
