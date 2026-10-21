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

/// 무기 이름 옆 표시: E등급은 "K2", "K2 +3", D등급은 +0도 "K2 D+0", "K2 D+3".
/// 등급 배지가 같이 보이는 화면은 [badge]를 켜서 D등급도 "K2 +0", "K2 +3"처럼 +N만 쓴다.
String withLevel(
  String name,
  int level, {
  Grade grade = Grade.e,
  bool badge = false,
}) => grade == Grade.d
    ? (badge ? '$name +$level' : '$name D+$level')
    : level > 0
    ? '$name +$level'
    : name;

/// 저장된 등급 글자("E"/"D") → [Grade]. 없거나 모르면 E.
Grade gradeFromString(String? g) => g == 'D' ? Grade.d : Grade.e;
