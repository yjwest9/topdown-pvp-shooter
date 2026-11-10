import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/cover.dart';
import 'package:topsoldier/rules/melee.dart';
import 'package:topsoldier/rules/movement.dart';
import 'package:topsoldier/rules/weapon_state.dart';

CoverBody body(double x, double y, {bool crouching = false}) =>
    (pos: (x: x, y: y), crouching: crouching, airborne: false, onCrate: false);

MeleeTarget target(
  Object key,
  double x,
  double y, {
  Stance stance = Stance.standing,
  bool protected = false,
  bool ally = false,
}) => (
  key: key,
  body: body(x, y, crouching: stance == Stance.crouching),
  stance: stance,
  protected: protected,
  ally: ally,
);

List<Object> swing(
  List<MeleeTarget> ts, {
  double angle = 0,
  List<Box> walls = const [],
  List<Box> crates = const [],
  CoverBody? me,
}) => meleeHits(
  attacker: me ?? body(0, 0),
  angle: angle,
  weapon: knife,
  targets: ts,
  highWalls: walls,
  lowCrates: crates,
);

void main() {
  group('knife data (decisions 6장)', () {
    test('numbers', () {
      expect(knife.family, WeaponFamily.melee);
      expect(knife.damage, 40);
      expect(knife.fireInterval, 0.40);
      expect(knife.range, 80);
      expect(knife.spread, closeTo(pi / 3, 1e-9));
      expect(knife.moveSpeed, 1.15);
      expect(knife.critChance, 0.15);
      expect(knife.critMultiplier, 2.0);
      expect(weaponById('knife'), knife);
    });
    test('no ammo, no reload', () {
      final s = WeaponState(knife);
      expect(s.tryFire(), true);
      expect(s.tryFire(), false); // 간격 0.4초
      s.tick(0.39);
      expect(s.tryFire(), false);
      s.tick(0.02);
      expect(s.tryFire(), true);
      expect(s.reloading, false);
      s.reload();
      expect(s.reloading, false);
      s.tick(10);
      expect(s.reloading, false);
    });
  });

  group('arc hit', () {
    test('range edge: body edge within 80px', () {
      // 서 있는 반경 16: 중심 96까지 닿는다.
      expect(swing([target('a', 96, 0)]), ['a']);
      expect(swing([target('a', 96.5, 0)]), isEmpty);
      // 앉으면 반경 11.2
      expect(swing([target('a', 91, 0, stance: Stance.crouching)]), ['a']);
      expect(swing([target('a', 92, 0, stance: Stance.crouching)]), isEmpty);
    });
    test('angle edge: ±30° around aim', () {
      Object? at(double deg) {
        final r = deg * pi / 180;
        final h = swing([target('a', 60 * cos(r), 60 * sin(r))]);
        return h.isEmpty ? null : h.single;
      }

      expect(at(0), 'a');
      expect(at(29.9), 'a');
      expect(at(-29.9), 'a');
      expect(at(30.1), isNull);
      expect(at(-30.1), isNull);
      expect(at(45), isNull); // 예전 90도 폭이면 맞았을 각도
      expect(at(180), isNull);
    });
    test('angle wraps around ±pi', () {
      final h = swing([target('a', -60, 1)], angle: pi);
      expect(h, ['a']);
    });
    test('target on top of me is hit', () {
      expect(swing([target('a', 0, 0)]), ['a']);
    });
    test('several targets, allies skipped, protected ignored', () {
      final h = swing([
        target('a', 50, 0),
        target('b', 50, 20),
        target('ally', 50, -10, ally: true),
        target('prot', 60, 0, protected: true),
        target('far', 300, 0),
      ]);
      expect(h, ['a', 'b']);
    });
  });

  group('blocking', () {
    const wall = (left: 30.0, top: -50.0, right: 40.0, bottom: 50.0);
    const crate = (left: 30.0, top: -20.0, right: 50.0, bottom: 20.0);

    test('high wall between blocks the hit', () {
      expect(swing([target('a', 80, 0)], walls: [wall]), isEmpty);
      expect(swing([target('a', 80, 0)]), ['a']);
    });
    test('crouching target right behind a low crate is hidden', () {
      final t = target('a', 70, 0, stance: Stance.crouching);
      expect(swing([t], crates: [crate]), isEmpty);
    });
    test('standing target behind a low crate is hit', () {
      expect(swing([target('a', 70, 0)], crates: [crate]), ['a']);
    });
    test('attacker crouching behind the crate cannot hit over it', () {
      final me = body(15, 0, crouching: true);
      expect(swing([target('a', 80, 0)], crates: [crate], me: me), isEmpty);
    });
    test('attacker on top of the crate hits a hidden target', () {
      const me = (
        pos: (x: 10.0, y: 0.0),
        crouching: false,
        airborne: false,
        onCrate: true,
      );
      final t = target('a', 70, 0, stance: Stance.crouching);
      expect(swing([t], crates: [crate], me: me), ['a']);
    });
  });
}
