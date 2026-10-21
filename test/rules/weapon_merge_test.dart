import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/combat.dart';
import 'package:topsoldier/rules/upgrade.dart';
import 'package:topsoldier/rules/weapon_merge.dart';

MergeWeapon w(
  String id, {
  WeaponFamily family = WeaponFamily.rifle,
  Grade grade = Grade.e,
  int level = 5,
  bool equipped = false,
}) => (id: id, family: family, grade: grade, level: level, equipped: equipped);

void main() {
  const gold = mergeCost;

  test('cost is 15,000 G (decisions 7장)', () => expect(mergeCost, 15000));

  group('isMergeable: E+5 of rifle / sniper / shotgun only', () {
    test('E+5 of the three families', () {
      for (final f in [
        WeaponFamily.rifle,
        WeaponFamily.sniper,
        WeaponFamily.shotgun,
      ]) {
        expect(isMergeable(w('a', family: f)), true, reason: '$f');
      }
    });

    test('pistol, E+4, and D grade are not', () {
      expect(isMergeable(w('a', family: WeaponFamily.pistol)), false);
      expect(isMergeable(w('a', level: 4)), false);
      expect(isMergeable(w('a', grade: Grade.d)), false);
      expect(isMergeable(w('a', grade: Grade.d, level: 0)), false);
    });
  });

  group('checkMerge', () {
    test('two different E+5 of the same family with enough gold → ok', () {
      expect(
        checkMerge(base: w('a'), material: w('b'), gold: gold),
        MergeCheck.ok,
      );
    });

    test('the base may be equipped; the material may not', () {
      expect(
        checkMerge(base: w('a', equipped: true), material: w('b'), gold: gold),
        MergeCheck.ok,
      );
      expect(
        checkMerge(base: w('a'), material: w('b', equipped: true), gold: gold),
        MergeCheck.materialEquipped,
      );
    });

    test('the same individual cannot be both', () {
      expect(
        checkMerge(base: w('a'), material: w('a'), gold: gold),
        MergeCheck.sameWeapon,
      );
    });

    test('different family → no', () {
      expect(
        checkMerge(
          base: w('a'),
          material: w('b', family: WeaponFamily.sniper),
          gold: gold,
        ),
        MergeCheck.differentFamily,
      );
    });

    test('either one not E+5 → no (E+4, D grade, pistol)', () {
      expect(
        checkMerge(base: w('a'), material: w('b', level: 4), gold: gold),
        MergeCheck.notMergeable,
      );
      expect(
        checkMerge(base: w('a', level: 4), material: w('b'), gold: gold),
        MergeCheck.notMergeable,
      );
      expect(
        checkMerge(
          base: w('a'),
          material: w('b', grade: Grade.d, level: 5),
          gold: gold,
        ),
        MergeCheck.notMergeable,
      );
      expect(
        checkMerge(
          base: w('a', family: WeaponFamily.pistol),
          material: w('b', family: WeaponFamily.pistol),
          gold: gold,
        ),
        MergeCheck.notMergeable,
      );
    });

    test('gold: 14,999 is not enough, 15,000 is', () {
      expect(
        checkMerge(base: w('a'), material: w('b'), gold: mergeCost - 1),
        MergeCheck.notEnoughGold,
      );
      expect(
        checkMerge(base: w('a'), material: w('b'), gold: mergeCost),
        MergeCheck.ok,
      );
    });
  });

  test('merged weapon is D+0, same damage as E+5; D upgrades go on to D+5', () {
    final r = mergedResult();
    expect((r.grade, r.level), (Grade.d, 0));
    expect(gradeMultiplier(r.grade, r.level), gradeMultiplier(Grade.e, 5));
    expect(gradeMultiplier(Grade.d, 5), closeTo(1.20, 1e-9));
  });

  group('names beside the weapon: "+N" for E, "D+N" for D', () {
    test('E keeps the old look', () {
      expect(withLevel('K2', 0), 'K2');
      expect(withLevel('K2', 3), 'K2 +3');
    });

    test('D always shows the grade, even at +0', () {
      expect(withLevel('K2', 0, grade: Grade.d), 'K2 D+0');
      expect(withLevel('K2', 3, grade: Grade.d), 'K2 D+3');
    });

    test('with a grade badge beside it: "+N" only (D too), E unchanged', () {
      expect(withLevel('K2', 0, grade: Grade.d, badge: true), 'K2 +0');
      expect(withLevel('K2', 3, grade: Grade.d, badge: true), 'K2 +3');
      expect(withLevel('K2', 0, badge: true), 'K2');
      expect(withLevel('K2', 3, badge: true), 'K2 +3');
    });

    test('stored grade string → Grade', () {
      expect(gradeFromString('D'), Grade.d);
      expect(gradeFromString('E'), Grade.e);
      expect(gradeFromString(null), Grade.e);
    });
  });
}
