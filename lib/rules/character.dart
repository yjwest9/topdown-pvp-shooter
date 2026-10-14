import 'balance.dart';

/// 강화 [level](0~5)을 반영한 최종 능력치.
CharacterStats upgradedCharacter(CharacterStats c, int level) {
  if (level < 0 || level > maxUpgradeLevel) {
    throw ArgumentError.value(level, 'level', 'must be 0..$maxUpgradeLevel');
  }
  return CharacterStats(
    id: c.id,
    name: c.name,
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

/// 저장된 캐릭터 id와 단계로 능력치. 모르는 id나 0~5 밖 단계(옛 데이터·조작)는 기본 병사 +0.
CharacterStats characterStats(String? id, int level) {
  for (final c in characters) {
    if (c.id == id && level >= 0 && level <= maxUpgradeLevel) {
      return upgradedCharacter(c, level);
    }
  }
  return basicSoldier;
}
