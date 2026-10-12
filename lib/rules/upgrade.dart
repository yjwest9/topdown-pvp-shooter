import 'balance.dart';

/// 강화(decisions 7장). [level]은 지금 단계 0~4.
int upgradeCost(int level) => upgradeCosts[level];
double upgradeChance(int level) => upgradeChances[level];

enum UpgradeOutcome { success, fail, notEnoughGold, maxLevel }

/// [roll]은 0~1 난수(밖에서 굴린다). [roll] < 성공률이면 성공.
UpgradeOutcome tryUpgrade({
  required int level,
  required int gold,
  required double roll,
}) {
  if (level >= maxUpgradeLevel) return UpgradeOutcome.maxLevel;
  if (gold < upgradeCost(level)) return UpgradeOutcome.notEnoughGold;
  return roll < upgradeChance(level)
      ? UpgradeOutcome.success
      : UpgradeOutcome.fail;
}

/// 무기 이름 옆 강화 단계: "K2", "K2 +3".
String withLevel(String name, int level) => level > 0 ? '$name +$level' : name;
