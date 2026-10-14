import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/models/room.dart';
import 'package:topsoldier/game/net/interpolation.dart';

NetState s(int t, double x, double y, double a, {double up = 0}) => NetState(
  x: x,
  y: y,
  a: a,
  stance: 'standing',
  up: up,
  weapon: 'rifle_standard',
  t: t,
);

double deg(double d) => d * pi / 180;

void main() {
  test('halfway between two snapshots', () {
    final r = sample([s(1000, 0, 0, 0), s(1100, 100, 50, 1, up: 1)], 1050)!;
    expect(r.x, closeTo(50, 1e-9));
    expect(r.y, closeTo(25, 1e-9));
    expect(r.a, closeTo(0.5, 1e-9));
    expect(r.up, closeTo(0.5, 1e-9));
  });

  test('angle 359° → 1° goes the short way through 0°', () {
    final mid = lerpAngle(deg(359), deg(1), 0.5);
    // 0° (= 360°)이어야 한다. 180°면 반대로 돈 것.
    expect(cos(mid), closeTo(1, 1e-9));
    expect(lerpAngle(deg(359), deg(1), 0.25), closeTo(deg(359.5), 1e-9));
  });

  test('picks the pair around the time in a longer buffer', () {
    final r = sample([
      s(1000, 0, 0, 0),
      s(1066, 66, 0, 0),
      s(1133, 133, 0, 0),
    ], 1100)!;
    expect(r.x, closeTo(100, 1e-9));
  });

  test('before the first / after the last snapshot holds the edge', () {
    final buf = [s(1000, 10, 0, 0), s(1100, 20, 0, 0)];
    expect(sample(buf, 900)!.x, 10);
    expect(sample(buf, 1500)!.x, 20); // 예측(외삽)은 안 한다
    expect(sample([], 1000), isNull);
  });

  group('reloading flag rl (decisions 3장)', () {
    NetState r(int t, {required bool reloading}) => NetState(
      x: 0,
      y: 0,
      a: 0,
      stance: 'standing',
      up: 0,
      weapon: 'rifle_standard',
      reloading: reloading,
      t: t,
    );

    test('sent as rl, missing (old app) reads as false', () {
      expect(r(0, reloading: true).toJson()['rl'], true);
      final old = NetState.fromJson({
        'x': 1,
        'y': 2,
        'a': 0,
        'stance': 'standing',
        'up': 0,
        'weapon': 'pistol',
        't': 5,
      });
      expect(old.reloading, false);
      expect(NetState.fromJson(r(5, reloading: true).toJson()).reloading, true);
    });

    test('between two snapshots it follows the earlier one', () {
      final buf = [r(1000, reloading: true), r(1100, reloading: false)];
      expect(sample(buf, 1050)!.reloading, true);
      expect(sample(buf, 1200)!.reloading, false); // 뒤 스냅샷 이후
    });
  });
}
