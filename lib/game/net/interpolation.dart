import 'dart:math';

import '../../data/models/room.dart';

/// [a]에서 [b]로 최단 방향 회전해서 [f](0~1)만큼 간 각도.
double lerpAngle(double a, double b, double f) {
  var d = (b - a) % (2 * pi); // 0 ≤ d < 2π
  if (d > pi) d -= 2 * pi;
  return a + d * f;
}

/// 시간순 [buffer]에서 서버 시간 [t]의 상태. 두 스냅샷 사이는 보간,
/// 범위 밖이면 가장 가까운 끝 값(외삽 안 함). 자세·무기는 앞 스냅샷 값.
NetState? sample(List<NetState> buffer, int t) {
  if (buffer.isEmpty) return null;
  if (t <= buffer.first.t) return buffer.first;
  for (var i = 1; i < buffer.length; i++) {
    final b = buffer[i];
    if (b.t < t) continue;
    final a = buffer[i - 1];
    final f = (t - a.t) / (b.t - a.t);
    return NetState(
      x: a.x + (b.x - a.x) * f,
      y: a.y + (b.y - a.y) * f,
      a: lerpAngle(a.a, b.a, f),
      stance: a.stance,
      up: a.up + (b.up - a.up) * f,
      weapon: a.weapon,
      t: t,
    );
  }
  return buffer.last;
}
