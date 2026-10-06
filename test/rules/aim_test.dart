import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/aim.dart';
import 'package:topsoldier/rules/balance.dart';
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

void main() {
  group('spread half-angle', () {
    test('rifle: base x stance', () {
      expect(spreadHalfAngle(rifleStandard, Stance.standing), 0.035);
      expect(
        spreadHalfAngle(rifleStandard, Stance.crouching),
        closeTo(0.014, 1e-12),
      );
      expect(
        spreadHalfAngle(rifleStandard, Stance.walking),
        closeTo(0.0875, 1e-12),
      );
      expect(
        spreadHalfAngle(rifleStandard, Stance.jumping),
        closeTo(0.14, 1e-12),
      );
    });

    test('light sniper halves only while moving', () {
      expect(spreadHalfAngle(sniperLight, Stance.standing), 0.008);
      expect(spreadHalfAngle(sniperLight, Stance.crouching), 0.008 * 0.4);
      expect(spreadHalfAngle(sniperLight, Stance.walking), 0.008 * 2.5 * 0.5);
      expect(spreadHalfAngle(sniperLight, Stance.jumping), 0.008 * 4 * 0.5);
    });

    test('shotgun: half of the fan width x stance', () {
      expect(spreadHalfAngle(shotgunPump, Stance.standing), 0.125);
      expect(
        spreadHalfAngle(shotgunPump, Stance.crouching),
        closeTo(0.125 * 0.4, 1e-12),
      );
    });
  });

  group('shotAngles', () {
    test('single bullet stays within +-spread', () {
      for (final roll in [0.0, 0.25, 0.5, 0.999]) {
        final a = shotAngles(
          rifleStandard,
          Stance.standing,
          aim: 1,
          roll: roll,
        );
        expect(a, hasLength(1));
        expect(a.single, inInclusiveRange(1 - 0.035, 1 + 0.035));
      }
      expect(
        shotAngles(rifleStandard, Stance.standing, aim: 1, roll: 0).single,
        closeTo(1 - 0.035, 1e-12),
      );
      expect(
        shotAngles(rifleStandard, Stance.standing, aim: 1, roll: 0.5).single,
        closeTo(1, 1e-12),
      );
    });

    for (final (w, n) in [
      (shotgunPump, 8),
      (shotgunAuto, 8),
      (shotgunDouble, 10),
    ]) {
      test('${w.id}: $n pellets spread evenly over the fan', () {
        final a = shotAngles(w, Stance.standing, aim: 0, roll: 0.3);
        expect(a, hasLength(n));
        expect(a.first, closeTo(-w.spread / 2, 1e-12));
        expect(a.last, closeTo(w.spread / 2, 1e-12));
        final step = w.spread / (n - 1);
        for (var i = 1; i < n; i++) {
          expect(a[i] - a[i - 1], closeTo(step, 1e-12));
        }
      });
    }

    test('stance scales the shotgun fan', () {
      final a = shotAngles(shotgunPump, Stance.crouching, aim: 0, roll: 0);
      expect(a.last - a.first, closeTo(0.25 * 0.4, 1e-12));
    });
  });

  test('pellet damage = max damage / pellets', () {
    expect(shotgunPump.pelletDamage, 11);
    expect(shotgunAuto.pelletDamage, 6);
    expect(shotgunDouble.pelletDamage, 11);
    expect(rifleStandard.pelletDamage, 13);
  });

  group('autoFireTarget', () {
    final shooter = body(0, 0);
    const walls = <Box>[];
    const crates = <Box>[];

    int? pick(
      List<CoverBody> targets, {
      double aim = 0,
      double range = 560,
      List<Box> highWalls = walls,
      List<Box> lowCrates = crates,
      CoverBody? from,
    }) => autoFireTarget(
      shooter: from ?? shooter,
      aim: aim,
      range: range,
      targets: targets,
      highWalls: highWalls,
      lowCrates: lowCrates,
    );

    test('picks the closest target within +-0.14 rad', () {
      expect(pick([body(300, 0), body(200, 10)]), 1);
    });

    test('outside the angle', () {
      // atan(50/300) = 0.165 > 0.14
      expect(pick([body(300, 50)]), isNull);
      // 0.1 rad 안
      expect(pick([body(300, 30)]), 0);
    });

    test('angle wraps around pi', () {
      expect(pick([body(-300, -1)], aim: pi), 0);
      expect(pick([body(-300, 1)], aim: -pi), 0);
    });

    test('outside the range', () {
      expect(pick([body(561, 0)]), isNull);
      expect(pick([body(560, 0)]), 0);
    });

    test('behind a high wall', () {
      const wall = (left: 100.0, top: -50.0, right: 130.0, bottom: 50.0);
      expect(pick([body(300, 0)], highWalls: [wall]), isNull);
      expect(pick([body(300, 0), body(80, 0)], highWalls: [wall]), 1);
    });

    test('crouched right behind low cover is not picked', () {
      const crate = (left: 200.0, top: -25.0, right: 250.0, bottom: 25.0);
      expect(pick([body(280, 0, crouching: true)], lowCrates: [crate]), isNull);
      expect(pick([body(280, 0)], lowCrates: [crate]), 0);
      // 쏘는 사람이 상자 뒤에 숨어 있으면 상대도 못 쏜다
      expect(
        pick(
          [body(-100, 0)],
          aim: pi,
          lowCrates: [crate],
          from: body(280, 0, crouching: true),
        ),
        isNull,
      );
      // 쏘는 사람이 상자 위면 보인다
      expect(
        pick(
          [body(280, 0, crouching: true)],
          lowCrates: [crate],
          from: body(0, 0, onCrate: true),
        ),
        0,
      );
    });
  });
}
