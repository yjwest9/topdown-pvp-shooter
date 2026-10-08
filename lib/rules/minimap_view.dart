import 'dart:math';

/// 회전 모드에서 미니맵을 확대하는 배율(내 주변만 보인다).
const minimapZoom = 1.8;

/// 월드를 미니맵으로 옮길 때 돌릴 각도(라디안, 화면 기준 시계 방향).
///
/// - 회전 모드(발로란트식): 내가 보는 쪽이 늘 위.
/// - 고정 모드: 내 진영이 늘 아래. 맵이 180도 대칭이라 B팀(북쪽 진영)은
///   180도 뒤집으면 A팀과 똑같은 모습이 된다.
double minimapRotation({
  required bool rotating,
  required bool teamA,
  required double playerAngle,
}) {
  if (rotating) return -pi / 2 - playerAngle;
  return teamA ? 0 : pi;
}
