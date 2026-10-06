import 'balance.dart';

double spreadMultiplier(Stance s) => stanceStats[s]!.spread;

bool canFire(Stance s) => stanceStats[s]!.canFire;

/// 5% + 상대 회피 − 내 명중 (+ 상대가 점프 중이면 10%p), 0~20%.
double missChance({
  required double accuracy,
  required double evasion,
  bool airborne = false,
}) => (missChanceBase + evasion - accuracy + (airborne ? jumpMissBonus : 0))
    .clamp(missChanceMin, missChanceMax);

/// 무기 크리 + 캐릭터 크리, 상한 [critChanceCap].
double critChance({
  required double weaponCrit,
  required double characterCrit,
}) => (weaponCrit + characterCrit).clamp(0.0, critChanceCap);

double gradeMultiplier(Grade g, int level) {
  if (level < 0 || level > maxUpgradeLevel) {
    throw ArgumentError.value(level, 'level', 'must be 0..$maxUpgradeLevel');
  }
  return gradeBaseMultiplier[g]! + level * damagePerUpgradeLevel;
}

class HitResult {
  const HitResult({
    required this.miss,
    required this.crit,
    required this.damage,
  });

  final bool miss;
  final bool crit;
  final double damage;
}

/// 랜덤 값([missRoll], [critRoll], 0~1)은 호출하는 쪽에서 굴려서 넣는다.
HitResult resolveHit({
  required double baseDamage,
  required double critMultiplier,
  required double gradeMultiplier,
  required double missChance,
  required double critChance,
  required double missRoll,
  required double critRoll,
}) {
  if (missRoll < missChance) {
    return const HitResult(miss: true, crit: false, damage: 0);
  }
  final crit = critRoll < critChance;
  return HitResult(
    miss: false,
    crit: crit,
    damage: baseDamage * gradeMultiplier * (crit ? critMultiplier : 1),
  );
}

int shotsToKill(double damage, double hp) => (hp / damage).ceil();

/// (필요 발수 − 1) × 연사 간격, 체력 100 기준.
double ttk(WeaponStats w) => (shotsToKill(w.damage, 100) - 1) * w.fireInterval;
