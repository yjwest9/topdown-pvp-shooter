import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/minimap_view.dart';

void main() {
  /// 월드의 [dir] 방향 벡터를 [rot]만큼 돌린 화면 방향(y 아래가 +).
  ({double x, double y}) rotate(double dir, double rot) =>
      (x: cos(dir + rot), y: sin(dir + rot));

  group('fixed mode: my base is always at the bottom', () {
    test('team A keeps north up', () {
      expect(
        minimapRotation(rotating: false, teamA: true, playerAngle: 1.2),
        0,
      );
    });

    test('team B is flipped 180 degrees, whatever the heading', () {
      for (final a in [0.0, 1.2, -pi / 2]) {
        expect(
          minimapRotation(rotating: false, teamA: false, playerAngle: a),
          pi,
        );
      }
    });

    test('team B sees the map exactly as team A (180 degree symmetry)', () {
      // A의 진영은 남쪽(아래). B의 진영은 북쪽(위)이지만 뒤집으면 아래가 된다.
      const north = -pi / 2;
      final b = rotate(north, pi);
      expect(b.x, closeTo(0, 1e-9));
      expect(b.y, closeTo(1, 1e-9)); // 월드 북쪽이 화면 아래로
    });
  });

  group('rotating mode: facing direction is up', () {
    test('any heading ends up pointing to the top of the minimap', () {
      for (final a in [0.0, pi / 2, pi, -pi / 2, 2.3, -0.7]) {
        final up = rotate(
          a,
          minimapRotation(rotating: true, teamA: true, playerAngle: a),
        );
        expect(up.x, closeTo(0, 1e-9), reason: 'heading $a');
        expect(up.y, closeTo(-1, 1e-9), reason: 'heading $a');
      }
    });

    test('team does not matter, the heading already decides', () {
      expect(
        minimapRotation(rotating: true, teamA: false, playerAngle: 0.4),
        minimapRotation(rotating: true, teamA: true, playerAngle: 0.4),
      );
    });
  });
}
