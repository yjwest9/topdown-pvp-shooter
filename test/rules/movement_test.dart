import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/movement.dart';

void main() {
  group('moveDelta', () {
    for (final a in [0.0, pi / 2, pi]) {
      test('forward at angle $a -> (cos a, sin a) x distance', () {
        final d = moveDelta(angle: a, forward: 1, strafe: 0, distance: 220);
        expect(d.x, closeTo(cos(a) * 220, 1e-9));
        expect(d.y, closeTo(sin(a) * 220, 1e-9));
      });
    }

    test('strafe right is 90 degrees clockwise from forward', () {
      // facing +x (east): right is +y (south)
      final d = moveDelta(angle: 0, forward: 0, strafe: 1, distance: 10);
      expect(d.x, closeTo(0, 1e-9));
      expect(d.y, closeTo(10, 1e-9));
    });

    test('diagonal input longer than 1 is clamped', () {
      final d = moveDelta(angle: 0, forward: 1, strafe: 1, distance: 10);
      expect(sqrt(d.x * d.x + d.y * d.y), closeTo(10, 1e-9));
    });

    test('analog input below 1 moves less', () {
      final d = moveDelta(angle: 0, forward: 0.5, strafe: 0, distance: 10);
      expect(d.x, closeTo(5, 1e-9));
    });
  });

  group('turn', () {
    test('dx x 0.0075 x (sensitivity / 5)', () {
      expect(turn(0, dragDx: 100, sensitivity: 5), closeTo(0.75, 1e-9));
      expect(turn(0, dragDx: 100, sensitivity: 10), closeTo(1.5, 1e-9));
      expect(turn(1, dragDx: -100, sensitivity: 5), closeTo(0.25, 1e-9));
    });
  });

  group('collision', () {
    const box = (left: 100.0, top: 100.0, right: 200.0, bottom: 200.0);

    test('circleOverlapsBox', () {
      expect(circleOverlapsBox((x: 150, y: 150), 16, box), isTrue);
      expect(circleOverlapsBox((x: 90, y: 150), 16, box), isTrue);
      expect(circleOverlapsBox((x: 84, y: 150), 16, box), isFalse);
      // corner: distance to (100,100) is sqrt(200) ~ 14.1 < 16
      expect(circleOverlapsBox((x: 90, y: 90), 16, box), isTrue);
      expect(circleOverlapsBox((x: 85, y: 85), 16, box), isFalse);
    });

    test('slide stops on the blocked axis only', () {
      // moving right-down into the left face of the box
      final p = slide((x: 80, y: 150), (x: 10, y: 5), 16, [box]);
      expect(p.x, 80); // x blocked
      expect(p.y, 155); // y still moves
    });

    test('slide moves freely when nothing is hit', () {
      final p = slide((x: 0, y: 0), (x: 3, y: 4), 16, [box]);
      expect(p, (x: 3.0, y: 4.0));
    });
  });

  test('walk speed comes from balance', () {
    expect(walkSpeed, 220);
    expect(playerRadius, 16);
  });
}
