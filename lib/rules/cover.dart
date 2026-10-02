import 'dart:math';

import 'balance.dart';
import 'movement.dart';

/// 엄폐 판정에 필요한 병사 상태 (decisions 4장).
typedef CoverBody = ({Vec pos, bool crouching, bool airborne, bool onCrate});

/// 선분 [a]→[b]가 사각형을 지나는지 (slab 방식).
bool segmentHitsBox(Vec a, Vec b, Box box) {
  var t0 = 0.0, t1 = 1.0;
  bool clip(double p, double d, double lo, double hi) {
    if (d == 0) return p >= lo && p <= hi;
    var ta = (lo - p) / d, tb = (hi - p) / d;
    if (ta > tb) (ta, tb) = (tb, ta);
    t0 = max(t0, ta);
    t1 = min(t1, tb);
    return t0 <= t1;
  }

  return clip(a.x, b.x - a.x, box.left, box.right) &&
      clip(a.y, b.y - a.y, box.top, box.bottom);
}

/// 높은 벽은 자세와 상관없이 시야·총알을 막는다.
bool lineBlockedByHighWall(Vec from, Vec to, List<Box> highWalls) =>
    highWalls.any((w) => segmentHitsBox(from, to, w));

/// [target]이 낮은 상자 바로 뒤(50px 이내)에 앉아 있어서 [viewer]에게 안 보이는지.
/// 둘 중 누구라도 상자 위거나 target이 공중이면 숨지 못한다.
bool hiddenBehindLowCover(
  CoverBody target,
  CoverBody viewer,
  List<Box> lowCrates,
) {
  if (!target.crouching || target.airborne) return false;
  if (target.onCrate || viewer.onCrate) return false;
  return lowCrates.any(
    (c) =>
        distanceToBox(target.pos, c) <= lowCoverRange &&
        segmentHitsBox(viewer.pos, target.pos, c),
  );
}

/// 총알도 시야와 같은 규칙. 쏜 사람이 상자 위면 막히지 않는다.
bool bulletBlockedByLowCover({
  required CoverBody target,
  required CoverBody shooter,
  required List<Box> lowCrates,
}) => hiddenBehindLowCover(target, shooter, lowCrates);

double hitRadius(Stance s) =>
    s == Stance.crouching ? playerRadius * crouchHitRadiusScale : playerRadius;
