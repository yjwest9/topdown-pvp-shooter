import 'dart:math';

import 'balance.dart';
import 'combat.dart';
import 'cover.dart';
import 'movement.dart';

/// 조준선에서 벌어지는 최대 각도(rad). 단발 = ±이 안의 랜덤, 샷건 = 부채꼴 절반.
/// 퍼짐 = 기본 퍼짐 × 자세 배율 × (걷기·점프면 moveSpreadScale).
double spreadHalfAngle(WeaponStats w, Stance s) {
  final moving = s == Stance.walking || s == Stance.jumping;
  final spread =
      w.spread * spreadMultiplier(s) * (moving ? w.moveSpreadScale : 1);
  return w.pellets > 1 ? spread / 2 : spread;
}

/// 실제 발사 각도들. 단발은 [roll](0~1)로 퍼짐 안 랜덤, 샷건은 고르게 펼친 펠릿.
List<double> shotAngles(
  WeaponStats w,
  Stance s, {
  required double aim,
  required double roll,
}) {
  final h = spreadHalfAngle(w, s);
  if (w.pellets == 1) return [aim + (roll * 2 - 1) * h];
  return [
    for (var i = 0; i < w.pellets; i++) aim - h + i * 2 * h / (w.pellets - 1),
  ];
}

/// 자동 사격 대상의 index. 조준선 ±[autoFireAngle], 사거리 안, 높은 벽에 안 막히고
/// 낮은 상자 뒤에 숨지 않은 대상 중 가장 가까운 것. 없으면 null.
int? autoFireTarget({
  required CoverBody shooter,
  required double aim,
  required double range,
  required List<CoverBody> targets,
  required List<Box> highWalls,
  required List<Box> lowCrates,
}) {
  int? best;
  var bestDist = double.infinity;
  for (var i = 0; i < targets.length; i++) {
    final t = targets[i];
    final dx = t.pos.x - shooter.pos.x, dy = t.pos.y - shooter.pos.y;
    final d = sqrt(dx * dx + dy * dy);
    if (d > range || d >= bestDist) continue;
    final off = atan2(dy, dx) - aim;
    if (atan2(sin(off), cos(off)).abs() > autoFireAngle) continue;
    if (lineBlockedByHighWall(shooter.pos, t.pos, highWalls)) continue;
    if (hiddenBehindLowCover(t, shooter, lowCrates)) continue;
    if (hiddenBehindLowCover(shooter, t, lowCrates)) continue; // 양방향
    best = i;
    bestDist = d;
  }
  return best;
}
