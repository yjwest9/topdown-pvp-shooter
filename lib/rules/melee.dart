import 'dart:math';

import 'balance.dart';
import 'cover.dart';
import 'movement.dart';

/// 칼이 맞힐 수 있는 대상. [key]는 같은 대상인지 가리는 용도(`HitTarget`과 같음).
typedef MeleeTarget = ({
  Object key,
  CoverBody body,
  Stance stance,
  bool protected,
  bool ally,
});

/// [attacker]가 [angle] 방향으로 [weapon]을 휘둘렀을 때 맞는 대상의 key (decisions 6장).
/// 부채꼴: 몸 가장자리까지 거리 ≤ 사거리, 조준선과의 각도 ≤ 폭/2.
/// 높은 벽·낮은 상자는 총알과 같은 규칙으로 막는다. 아군·부활 보호 중인 대상은 맞지 않는다.
/// 미스·크리 굴림과 피해 적용은 부르는 쪽 몫.
List<Object> meleeHits({
  required CoverBody attacker,
  required double angle,
  required WeaponStats weapon,
  required List<MeleeTarget> targets,
  required List<Box> highWalls,
  required List<Box> lowCrates,
}) {
  final from = attacker.pos;
  bool blockedByCrate(MeleeTarget t, Box crate) =>
      segmentHitsBox(from, t.body.pos, crate) &&
      (shooterBehindCover(attacker, crate) ||
          bulletBlockedByLowCover(
            target: t.body,
            shooter: attacker,
            lowCrates: [crate],
          ));

  return [
    for (final t in targets)
      if (!t.ally && !t.protected)
        if (_inArc(from, angle, weapon, t))
          if (!lineBlockedByHighWall(from, t.body.pos, highWalls))
            if (!lowCrates.any((c) => blockedByCrate(t, c))) t.key,
  ];
}

bool _inArc(Vec from, double angle, WeaponStats weapon, MeleeTarget t) {
  final dx = t.body.pos.x - from.x, dy = t.body.pos.y - from.y;
  final dist = sqrt(dx * dx + dy * dy);
  if (dist - hitRadius(t.stance) > weapon.range) return false;
  if (dist == 0) return true;
  final diff = atan2(sin(atan2(dy, dx) - angle), cos(atan2(dy, dx) - angle));
  return diff.abs() <= weapon.spread / 2 + 1e-9;
}
