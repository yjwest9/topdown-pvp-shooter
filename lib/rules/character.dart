import 'balance.dart';

/// 강화 [level](0~5)을 반영한 최종 능력치.
CharacterStats upgradedCharacter(CharacterStats c, int level) {
  if (level < 0 || level > maxUpgradeLevel) {
    throw ArgumentError.value(level, 'level', 'must be 0..$maxUpgradeLevel');
  }
  return CharacterStats(
    id: c.id,
    hp: c.hp + c.hpPerLevel * level,
    accuracy: c.accuracy + c.accuracyPerLevel * level,
    evasion: c.evasion + c.evasionPerLevel * level,
    crit: c.crit + c.critPerLevel * level,
    moveSpeed: c.moveSpeed,
    hpPerLevel: c.hpPerLevel,
    accuracyPerLevel: c.accuracyPerLevel,
    evasionPerLevel: c.evasionPerLevel,
    critPerLevel: c.critPerLevel,
  );
}
