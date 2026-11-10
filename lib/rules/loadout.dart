import 'dart:math';

import 'balance.dart';

/// 무기 화면 능력치 막대(0~1). 각 값 ÷ [all] 중 최대값.
typedef StatBars = ({
  double damage,
  double fireRate,
  double range,
  double magazine,
  double mobility,
});

StatBars statBars(WeaponStats w, List<WeaponStats> all) {
  double bar(double Function(WeaponStats) f) => f(w) / all.map(f).reduce(max);
  return (
    damage: bar((x) => x.damage),
    fireRate: bar((x) => 1 / x.fireInterval),
    range: bar((x) => x.range),
    magazine: bar((x) => x.magazine.toDouble()),
    // 최대를 1.0으로 고정: 칼(×1.15)처럼 넘으면 꽉 찬 막대.
    mobility: min(1.0, w.moveSpeed),
  );
}
