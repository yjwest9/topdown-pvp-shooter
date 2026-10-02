import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/character.dart';
import 'package:topsoldier/rules/combat.dart';

/// 기대 발수 = 상대 체력 / (데미지 × 등급배율 × (1 − 미스) × (1 + 크리 × (크리배율 − 1)))
double expectedShots({
  required WeaponStats weapon,
  required double grade,
  required CharacterStats attacker,
  required CharacterStats defender,
}) {
  final miss = missChance(
    accuracy: attacker.accuracy,
    evasion: defender.evasion,
  );
  final crit = critChance(
    weaponCrit: weapon.critChance,
    characterCrit: attacker.crit,
  );
  final perShot =
      weapon.damage *
      grade *
      (1 - miss) *
      (1 + crit * (weapon.critMultiplier - 1));
  return defender.hp / perShot;
}

void main() {
  test('crit chance never exceeds cap', () {
    for (final w in weapons) {
      for (final c in characters) {
        final maxed = upgradedCharacter(c, maxUpgradeLevel);
        expect(
          critChance(weaponCrit: w.critChance, characterCrit: maxed.crit),
          lessThanOrEqualTo(critChanceCap),
          reason: '${w.id} + ${c.id}',
        );
      }
    }
  });

  group('growth gap (standard rifle) <= 2 shots', () {
    final newbie = upgradedCharacter(basicSoldier, 0);
    final newbieGrade = gradeMultiplier(Grade.e, 0);
    final maxGrade = gradeMultiplier(Grade.d, maxUpgradeLevel);

    for (final c in characters) {
      test(c.id, () {
        final maxed = upgradedCharacter(c, maxUpgradeLevel);
        final newbieKillsMax = expectedShots(
          weapon: rifleStandard,
          grade: newbieGrade,
          attacker: newbie,
          defender: maxed,
        );
        final maxKillsNewbie = expectedShots(
          weapon: rifleStandard,
          grade: maxGrade,
          attacker: maxed,
          defender: newbie,
        );
        final gap = newbieKillsMax - maxKillsNewbie;
        // ignore: avoid_print
        print(
          'gap ${c.id}: ${gap.toStringAsFixed(3)} '
          '(${newbieKillsMax.toStringAsFixed(3)} - '
          '${maxKillsNewbie.toStringAsFixed(3)})',
        );
        expect(gap, lessThanOrEqualTo(2.0));
      });
    }
  });
}
