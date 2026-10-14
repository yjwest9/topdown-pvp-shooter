import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/models/profile.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/character.dart';
import 'package:topsoldier/rules/combat.dart';

void main() {
  test('+5 upgrades', () {
    expect(upgradedCharacter(scout, 5).evasion, closeTo(0.13, 1e-9));
    expect(upgradedCharacter(marksman, 5).accuracy, closeTo(0.13, 1e-9));
    expect(upgradedCharacter(assault, 5).crit, closeTo(0.10, 1e-9));
    expect(upgradedCharacter(basicSoldier, 5).hp, 110);
  });

  test('+0 is the base character', () {
    expect(upgradedCharacter(basicSoldier, 0).hp, 100);
    expect(upgradedCharacter(scout, 0).evasion, closeTo(0.08, 1e-9));
  });

  test('upgrade only raises its own stat', () {
    final s = upgradedCharacter(scout, 5);
    expect(s.hp, 90);
    expect(s.accuracy, 0);
    expect(s.crit, 0);
  });

  test('level out of 0..5 throws', () {
    expect(() => upgradedCharacter(scout, 6), throwsArgumentError);
    expect(() => upgradedCharacter(scout, -1), throwsArgumentError);
  });

  test('character table has 4 characters', () {
    expect(characters, hasLength(4));
  });

  test('+5 scout moves 5% faster; upgrades never change speed', () {
    expect(upgradedCharacter(scout, 5).moveSpeed, 1.05);
    expect(upgradedCharacter(basicSoldier, 5).moveSpeed, 1.0);
  });

  test('+5 assault with a 25% crit weapon hits the 30% cap', () {
    final c = upgradedCharacter(assault, 5);
    expect(critChance(weaponCrit: 0.25, characterCrit: c.crit), 0.30);
  });

  test('jumping +5 scout: miss capped at 20%', () {
    final c = upgradedCharacter(scout, 5);
    expect(
      missChance(accuracy: 0, evasion: c.evasion, airborne: true),
      closeTo(0.20, 1e-9),
    );
  });

  test('names and price (decisions 8장)', () {
    expect(
      [for (final c in characters) c.name],
      ['기본 병사', '저격수', '정찰병', '돌격병'],
    );
    expect(characterPrice, 100);
  });

  test('characterStats: id + level, unknown id or bad level falls back', () {
    expect(characterStats('scout', 5).evasion, closeTo(0.13, 1e-9));
    expect(characterStats('nope', 3).hp, 100);
    expect(characterStats(null, 0).id, 'basic');
    expect(characterStats('basic', 9).hp, 100);
  });

  test('every character +0..+5 stays within the DB hp rule range', () {
    for (final c in characters) {
      for (var l = 0; l <= maxUpgradeLevel; l++) {
        final hp = upgradedCharacter(c, l).hp;
        expect(hp, inInclusiveRange(characterHpMin, characterHpMax));
      }
    }
    expect((characterHpMin, characterHpMax), (90, 110));
  });

  test('the profile default character is the basic soldier', () {
    expect(Profile.defaultCharacter, basicSoldier.id);
  });
}
