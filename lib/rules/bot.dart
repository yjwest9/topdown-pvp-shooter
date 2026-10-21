import 'dart:collection';
import 'dart:math';

import 'balance.dart';
import 'cover.dart';
import 'movement.dart';

/// 봇 길찾기용 격자(decisions 12장). 몸 원이 벽·상자에 안 닿는 칸만 지나간다.
class NavGrid {
  NavGrid({
    required this.width,
    required this.height,
    required this.blocks,
    this.cell = 70,
  }) : cols = width ~/ cell,
       rows = height ~/ cell {
    _open = [
      for (var i = 0; i < cols * rows; i++)
        walkable(_center(i % cols, i ~/ cols)),
    ];
  }

  final double width;
  final double height;

  /// 높은 벽 + 낮은 상자(봇은 상자를 막힌 칸으로 본다).
  final List<Box> blocks;
  final double cell;
  final int cols;
  final int rows;
  late final List<bool> _open;

  bool walkable(Vec p) =>
      p.x >= playerRadius &&
      p.y >= playerRadius &&
      p.x <= width - playerRadius &&
      p.y <= height - playerRadius &&
      !blocks.any((b) => circleOverlapsBox(p, playerRadius, b));

  Vec _center(int cx, int cy) => (x: (cx + 0.5) * cell, y: (cy + 0.5) * cell);

  int _index(Vec p) {
    final cx = (p.x / cell).floor().clamp(0, cols - 1);
    final cy = (p.y / cell).floor().clamp(0, rows - 1);
    return cy * cols + cx;
  }

  /// [from]에서 [to]까지 지나갈 칸 중심들(출발 칸 제외, 도착 칸 포함). 4방향 BFS.
  /// 같은 칸이거나 못 가면 빈 목록.
  List<Vec> path(Vec from, Vec to) {
    final start = _index(from), goal = _index(to);
    if (start == goal || !_open[goal]) return const [];
    final prev = {start: start};
    final queue = Queue.of([start]);
    while (queue.isNotEmpty) {
      final i = queue.removeFirst();
      if (i == goal) break;
      final cx = i % cols, cy = i ~/ cols;
      for (final (nx, ny) in [
        (cx + 1, cy),
        (cx - 1, cy),
        (cx, cy + 1),
        (cx, cy - 1),
      ]) {
        if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) continue;
        final n = ny * cols + nx;
        if (!_open[n] || prev.containsKey(n)) continue;
        prev[n] = i;
        queue.add(n);
      }
    }
    if (!prev.containsKey(goal)) return const [];
    final cells = <Vec>[];
    for (var i = goal; i != start; i = prev[i]!) {
      cells.add(_center(i % cols, i ~/ cols));
    }
    return cells.reversed.toList();
  }
}

/// 위치 기록(시간 오름차순)에서 최근 [window]초 동안의 평균 속도(px/s).
/// 갑자기 방향을 바꾸면 한동안 예전 방향이 남는다(봇이 빗나가게, decisions 5장).
Vec averageVelocity(
  List<({double t, Vec p})> history, {
  required double window,
}) {
  if (history.length < 2) return (x: 0, y: 0);
  final last = history.last;
  final first = history.firstWhere((h) => h.t >= last.t - window - 1e-9);
  final dt = last.t - first.t;
  if (dt <= 0) return (x: 0, y: 0);
  return (x: (last.p.x - first.p.x) / dt, y: (last.p.y - first.p.y) / dt);
}

/// [velocity]로 움직이는 [target]을 맞히려면 쏠 각도. 총알 비행 시간만큼 앞을 노린다.
double leadAngle(Vec from, Vec target, Vec velocity) {
  final dx = target.x - from.x, dy = target.y - from.y;
  final t = sqrt(dx * dx + dy * dy) / bulletSpeed;
  return atan2(dy + velocity.y * t, dx + velocity.x * t);
}

/// [viewer]가 [target]을 보고 쏠 수 있는지: 사거리 안, 높은 벽 없음, 낮은 상자 숨기 양방향.
bool canSee(
  CoverBody viewer,
  CoverBody target, {
  required double range,
  required List<Box> highWalls,
  required List<Box> lowCrates,
}) {
  final dx = target.pos.x - viewer.pos.x, dy = target.pos.y - viewer.pos.y;
  if (dx * dx + dy * dy > range * range) return false;
  if (lineBlockedByHighWall(viewer.pos, target.pos, highWalls)) return false;
  return !hiddenBehindLowCover(target, viewer, lowCrates) &&
      !hiddenBehindLowCover(viewer, target, lowCrates);
}

/// [me]에서 [botCoverSearch] 안의 낮은 상자 중 [enemy] 반대편 자리. 가장 가까운 것.
/// 그 자리에 앉으면 상자에 숨는다. [walkable]이 아닌 자리는 건너뛴다. 없으면 null.
Vec? coverSpot(
  Vec me,
  Vec enemy,
  List<Box> crates, {
  required bool Function(Vec) walkable,
}) {
  Vec? best;
  var bestDist = double.infinity;
  for (final c in crates) {
    if (distanceToBox(me, c) > botCoverSearch) continue;
    final cx = (c.left + c.right) / 2, cy = (c.top + c.bottom) / 2;
    final dx = cx - enemy.x, dy = cy - enemy.y;
    final len = sqrt(dx * dx + dy * dy);
    if (len == 0) continue;
    final ux = dx / len, uy = dy / len;
    // 상자 가장자리 + 몸 반경 + 여유 8px만큼 상자 중심에서 떨어진 자리.
    final extent =
        ux.abs() * (c.right - c.left) / 2 + uy.abs() * (c.bottom - c.top) / 2;
    final k = extent + playerRadius + 8;
    final spot = (x: cx + ux * k, y: cy + uy * k);
    if (!walkable(spot)) continue;
    final d = sqrt(pow(spot.x - me.x, 2) + pow(spot.y - me.y, 2));
    if (d < bestDist) {
      best = spot;
      bestDist = d;
    }
  }
  return best;
}

/// 봇이 고를 수 있는 참가자(나, 다른 봇).
typedef BotCandidate = ({String id, String team, CoverBody body});

/// 고른 표적. [visible]이 false면 안 보이지만 길을 따라갈 방향이다.
typedef BotPick = ({String id, bool visible});

/// 봇전 2대2(decisions 12장): [myTeam]이 아닌 참가자 중 보이는 가장 가까운 적.
/// 아무도 안 보이면 가장 가까운 적(`visible: false`, 그쪽 길로 간다). 적이 없으면 null.
BotPick? pickTarget(
  CoverBody viewer,
  String myTeam,
  List<BotCandidate> candidates, {
  required double range,
  required List<Box> highWalls,
  required List<Box> lowCrates,
}) {
  double dist(CoverBody b) =>
      pow(b.pos.x - viewer.pos.x, 2) + pow(b.pos.y - viewer.pos.y, 2) + 0.0;
  BotPick? best;
  var bestDist = double.infinity;
  BotPick? bestAny;
  var bestAnyDist = double.infinity;
  for (final c in candidates) {
    if (c.team == myTeam) continue;
    final d = dist(c.body);
    if (d < bestAnyDist) {
      bestAny = (id: c.id, visible: false);
      bestAnyDist = d;
    }
    if (d < bestDist &&
        canSee(
          viewer,
          c.body,
          range: range,
          highWalls: highWalls,
          lowCrates: lowCrates,
        )) {
      best = (id: c.id, visible: true);
      bestDist = d;
    }
  }
  return best ?? bestAny;
}
