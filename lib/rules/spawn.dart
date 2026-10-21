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

double _nearest(Vec s, List<Vec> enemies) =>
    enemies.map((e) => sqrt(pow(e.x - s.x, 2) + pow(e.y - s.y, 2))).reduce(min);

/// 스폰을 "가장 가까운 적과의 거리가 먼 순서"로(같으면 원래 순서). 적을 모르면 원래 순서.
List<Vec> spawnsByDistance(List<Vec> spawns, List<Vec> enemies) {
  if (enemies.isEmpty) return List.of(spawns);
  final ranked = List.of(spawns);
  // 안정 정렬: 같은 거리면 앞에 있던 것이 먼저.
  final order = {for (var i = 0; i < ranked.length; i++) ranked[i]: i};
  ranked.sort((a, b) {
    final d = _nearest(b, enemies).compareTo(_nearest(a, enemies));
    return d != 0 ? d : order[a]!.compareTo(order[b]!);
  });
  return ranked;
}

/// 2대2 시작: 같은 팀 사람끼리 겹치지 않게 [allyIndex](uid 순서)번째로 먼 스폰.
Vec startSpawn(List<Vec> spawns, List<Vec> enemies, {required int allyIndex}) {
  final ranked = spawnsByDistance(spawns, enemies);
  return ranked[allyIndex % ranked.length];
}

/// 부활: 가장 먼 순서로 보되 아군이 이미 서 있는(반경 [occupiedRadius] 안) 스폰은 건너뛴다.
/// 모두 막혔으면 가장 먼 곳.
Vec respawnSpawn(
  List<Vec> spawns,
  List<Vec> enemies,
  List<Vec> allies, {
  double occupiedRadius = 80,
}) {
  final ranked = spawnsByDistance(spawns, enemies);
  bool taken(Vec s) => allies.any(
    (a) => sqrt(pow(a.x - s.x, 2) + pow(a.y - s.y, 2)) < occupiedRadius,
  );
  for (final s in ranked) {
    if (!taken(s)) return s;
  }
  return ranked.first;
}
