import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/combat.dart';
import 'package:topsoldier/rules/upgrade.dart';

void main() {
  test('cost and chance per step (decisions 7장)', () {
    expect(
      [for (var l = 0; l < 5; l++) upgradeCost(l)],
      [2000, 4000, 6000, 8000, 10000],
    );
    expect(
      [for (var l = 0; l < 5; l++) upgradeChance(l)],
      [0.9, 0.8, 0.7, 0.6, 0.5],
    );
  });

  group('tryUpgrade', () {
    test('roll under the chance → success', () {
      expect(
        tryUpgrade(level: 0, gold: 2000, roll: 0.89),
        UpgradeOutcome.success,
      );
    });

    test('roll at or over the chance → fail', () {
      expect(tryUpgrade(level: 0, gold: 2000, roll: 0.9), UpgradeOutcome.fail);
      expect(tryUpgrade(level: 4, gold: 99999, roll: 0.5), UpgradeOutcome.fail);
    });

    test('not enough gold, whatever the roll', () {
      expect(
        tryUpgrade(level: 2, gold: 5999, roll: 0),
        UpgradeOutcome.notEnoughGold,
      );
    });

    test('+5 is the max', () {
      expect(
        tryUpgrade(level: maxUpgradeLevel, gold: 1 << 30, roll: 0),
        UpgradeOutcome.maxLevel,
      );
    });
  });

  test('label shows the level only when upgraded', () {
    expect(withLevel('K2', 0), 'K2');
    expect(withLevel('K2', 3), 'K2 +3');
  });

  test('E+5 damage is 110% (13 → 14.3)', () {
    expect(
      rifleStandard.damage * gradeMultiplier(Grade.e, 5),
      closeTo(14.3, 1e-9),
    );
  });
}
