import 'dart:math';

import 'movement.dart';

/// 내 팀 스폰 중 가장 가까운 적과의 거리가 가장 먼 곳(decisions 11장).
/// 적을 모르면 첫 스폰.
Vec farthestSpawn(List<Vec> spawns, List<Vec> enemies) {
  if (enemies.isEmpty) return spawns.first;
  double nearest(Vec s) => enemies
      .map((e) => sqrt(pow(e.x - s.x, 2) + pow(e.y - s.y, 2)))
      .reduce(min);
  var best = spawns.first;
  for (final s in spawns.skip(1)) {
    if (nearest(s) > nearest(best)) best = s;
  }
  return best;
}
