import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/character.dart';

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
}
