import 'dart:math';

import 'balance.dart';

typedef Vec = ({double x, double y});
typedef Box = ({double left, double top, double right, double bottom});

/// 정면 기준 입력([forward] 앞+, [strafe] 오른쪽+)을 월드 이동량으로.
/// 각도 0 = +x. 입력 길이는 1로 자른다(대각선이 더 빠르지 않게).
Vec moveDelta({
  required double angle,
  required double forward,
  required double strafe,
  required double distance,
}) {
  final len = sqrt(forward * forward + strafe * strafe);
  final k = len > 1 ? distance / len : distance;
  final c = cos(angle), s = sin(angle);
  return (x: (forward * c - strafe * s) * k, y: (forward * s + strafe * c) * k);
}

/// 가로 드래그 [dragDx] px만큼 회전한 각도.
double turn(
  double angle, {
  required double dragDx,
  required double sensitivity,
}) => angle + dragDx * turnPerPixel * (sensitivity / defaultSensitivity);

bool pointInBox(Vec p, Box b) =>
    p.x >= b.left && p.x <= b.right && p.y >= b.top && p.y <= b.bottom;

/// 점에서 사각형까지 거리(안이면 0).
double distanceToBox(Vec p, Box b) {
  final dx = p.x - p.x.clamp(b.left, b.right);
  final dy = p.y - p.y.clamp(b.top, b.bottom);
  return sqrt(dx * dx + dy * dy);
}

bool circleOverlapsBox(Vec c, double r, Box b) {
  final dx = c.x - c.x.clamp(b.left, b.right);
  final dy = c.y - c.y.clamp(b.top, b.bottom);
  return dx * dx + dy * dy < r * r;
}

/// x축, y축을 따로 움직여서 막힌 축만 멈춘다(벽에 미끄러짐).
// ponytail: 한 프레임 이동량이 벽 두께보다 크면 뚫을 수 있음. 60fps 걷기는 4px라 문제없음.
Vec slide(Vec from, Vec delta, double r, List<Box> boxes) {
  bool blocked(Vec p) => boxes.any((b) => circleOverlapsBox(p, r, b));

  var p = from;
  final px = (x: p.x + delta.x, y: p.y);
  if (!blocked(px)) p = px;
  final py = (x: p.x, y: p.y + delta.y);
  if (!blocked(py)) p = py;
  return p;
}
