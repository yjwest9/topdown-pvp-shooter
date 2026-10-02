import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/combat.dart';

void main() {
  group('missChance', () {
    test('accuracy 0, evasion 0 -> base 5%', () {
      expect(missChance(accuracy: 0, evasion: 0), closeTo(0.05, 1e-9));
    });
    test('evasion adds', () {
      expect(missChance(accuracy: 0, evasion: 0.13), closeTo(0.18, 1e-9));
    });
    test('accuracy cancels evasion', () {
      expect(missChance(accuracy: 0.13, evasion: 0.13), closeTo(0.05, 1e-9));
    });
    test('clamped to 0%', () {
      expect(missChance(accuracy: 0.13, evasion: 0), closeTo(0.0, 1e-9));
    });
    test('clamped to 20%', () {
      expect(missChance(accuracy: 0, evasion: 0.30), closeTo(0.20, 1e-9));
    });
  });

  group('critChance', () {
    test('capped at 30%', () {
      expect(
        critChance(weaponCrit: 0.25, characterCrit: 0.10),
        closeTo(0.30, 1e-9),
      );
    });
    test('weapon + character', () {
      expect(
        critChance(weaponCrit: 0.10, characterCrit: 0.05),
        closeTo(0.15, 1e-9),
      );
    });
  });

  group('gradeMultiplier', () {
    test('E and D, level 0 and 5', () {
      expect(gradeMultiplier(Grade.e, 0), closeTo(1.00, 1e-9));
      expect(gradeMultiplier(Grade.e, 5), closeTo(1.10, 1e-9));
      expect(gradeMultiplier(Grade.d, 0), closeTo(1.10, 1e-9));
      expect(gradeMultiplier(Grade.d, 5), closeTo(1.20, 1e-9));
    });
    test('level out of 0..5 throws', () {
      expect(() => gradeMultiplier(Grade.e, 6), throwsArgumentError);
      expect(() => gradeMultiplier(Grade.e, -1), throwsArgumentError);
    });
  });

  group('stance', () {
    test('cannot fire while running', () {
      expect(canFire(Stance.running), isFalse);
      expect(canFire(Stance.standing), isTrue);
      expect(canFire(Stance.walking), isTrue);
      expect(canFire(Stance.crouching), isTrue);
      expect(canFire(Stance.jumping), isTrue);
    });
    test('spread multipliers', () {
      expect(spreadMultiplier(Stance.standing), 1.0);
      expect(spreadMultiplier(Stance.walking), 2.5);
      expect(spreadMultiplier(Stance.crouching), 0.4);
      expect(spreadMultiplier(Stance.jumping), 4.0);
    });
  });

  group('resolveHit', () {
    HitResult hit({required double missRoll, required double critRoll}) =>
        resolveHit(
          baseDamage: 13,
          critMultiplier: 2,
          gradeMultiplier: 1.1,
          missChance: 0.05,
          critChance: 0.10,
          missRoll: missRoll,
          critRoll: critRoll,
        );

    test('miss roll below miss chance -> miss, 0 damage', () {
      final r = hit(missRoll: 0.04, critRoll: 0.0);
      expect(r.miss, isTrue);
      expect(r.crit, isFalse);
      expect(r.damage, 0);
    });
    test('crit roll below crit chance -> damage x crit x grade', () {
      final r = hit(missRoll: 0.5, critRoll: 0.09);
      expect(r.miss, isFalse);
      expect(r.crit, isTrue);
      expect(r.damage, closeTo(13 * 2 * 1.1, 1e-9));
    });
    test('normal hit -> damage x grade', () {
      final r = hit(missRoll: 0.5, critRoll: 0.5);
      expect(r.miss, isFalse);
      expect(r.crit, isFalse);
      expect(r.damage, closeTo(13 * 1.1, 1e-9));
    });
  });

  group('shotsToKill', () {
    test('rounds up', () {
      expect(shotsToKill(13, 100), 8);
      expect(shotsToKill(25, 100), 4);
      expect(shotsToKill(110, 100), 1);
    });
  });

  group('ttk', () {
    final expected = {
      rifleStandard: 0.77,
      rifleRapid: 0.77,
      riflePrecision: 0.84,
      rifleHeavy: 0.60,
      sniperBolt: 1.30,
      sniperSemi: 0.90,
      sniperLight: 0.90,
    };
    for (final MapEntry(key: w, value: t) in expected.entries) {
      test(w.id, () => expect(ttk(w), closeTo(t, 0.01)));
    }
  });

  test('weapon table has 11 weapons with unique ids', () {
    expect(weapons, hasLength(11));
    expect(weapons.map((w) => w.id).toSet(), hasLength(11));
  });
}
