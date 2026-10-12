import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../../rules/minimap_view.dart';
import '../soldier_game.dart';

/// 왼쪽 위 미니맵(발로란트식). 배경 판 없이 반투명한 회색 맵 모양만 떠 있어 게임이 비쳐
/// 보인다. 벽은 진한 회색 + 밝은 테두리, 내 표시는 화살표 + 시야 부채꼴. 글자는 없다.
/// 두 가지 모드(눌러서 전환, 설정에도 있음):
/// - 회전: 동그란 창. 내 주변이 확대되고 내가 보는 쪽이 위. 시점을 돌리면 맵도 돈다.
/// - 고정: 맵 전체. 시점을 돌려도 맵은 그대로, 내 진영이 늘 아래(B팀은 180도 뒤집음).
/// 진영은 옅은 파랑(내 쪽)/빨강(상대 쪽). 상대 위치는 그리지 않는다.
class Minimap extends PositionComponent
    with HasGameReference<SoldierGame>, TapCallbacks {
  Minimap({required super.position}) : super(size: Vector2.all(side));

  /// 미니맵 한 변(px).
  static const side = 150.0;

  static final _disc = Paint()..color = const Color(0x40000000);
  static final _ring = Paint()
    ..color = const Color(0x40FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  static final _floor = Paint()..color = const Color(0x8CC9CDD3);
  static final _floorEdge = Paint()
    ..color = const Color(0xB3EEF0F2)
    ..style = PaintingStyle.stroke;
  static final _wall = Paint()..color = const Color(0xE6474C54);
  static final _wallEdge = Paint()
    ..color = const Color(0x80EEF0F2)
    ..style = PaintingStyle.stroke;
  static final _crate = Paint()..color = const Color(0xB38D939B);
  static final _mine = Paint()..color = const Color(0x404FA3E0);
  static final _enemy = Paint()..color = const Color(0x40E0563F);
  static final _view = Paint()..color = const Color(0x40FFFFFF);
  static final _me = Paint()..color = const Color(0xFF5DE0C8);
  static final _meEdge = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..style = PaintingStyle.stroke;

  @override
  void onTapUp(TapUpEvent event) => game.toggleMinimapMode();

  @override
  void render(Canvas canvas) {
    final map = game.map;
    final myTeam = game.match!.team;
    final rotating = game.minimapRotates;
    final p = game.player;
    // 고정 모드에서 맵 전체가 들어가는 배율. 회전 모드는 여기에 확대를 곱한다.
    final k = min(side / map.width, side / map.height);
    final zoom = rotating ? minimapZoom : 1.0;
    final rotation = minimapRotation(
      rotating: rotating,
      teamA: game.isTeamA,
      playerAngle: p.angle,
    );
    final me = Offset(p.position.x * k, p.position.y * k);
    Rect r(({double left, double top, double right, double bottom}) b) =>
        Rect.fromLTRB(b.left * k, b.top * k, b.right * k, b.bottom * k);
    const c = Offset(side / 2, side / 2);
    final line = 1 / zoom; // 확대해도 선 굵기는 같게

    canvas.save();
    if (rotating) {
      canvas
        ..drawCircle(c, side / 2, _disc)
        ..clipPath(
          Path()..addOval(Rect.fromCircle(center: c, radius: side / 2)),
        );
    }
    canvas
      ..translate(c.dx, c.dy)
      ..rotate(rotation)
      ..scale(zoom);
    // 회전 모드는 내가 중심, 고정 모드는 맵 전체가 중심.
    final center = rotating
        ? me
        : Offset(map.width * k / 2, map.height * k / 2);
    canvas.translate(-center.dx, -center.dy);

    final floor = Rect.fromLTWH(0, 0, map.width * k, map.height * k);
    canvas
      ..drawRect(floor, _floor)
      ..drawRect(floor, _floorEdge..strokeWidth = line);
    for (final b in map.bases) {
      canvas.drawRect(r(b.area), b.team == myTeam ? _mine : _enemy);
    }
    for (final cr in map.lowCrates) {
      canvas.drawRect(r(cr), _crate);
    }
    for (final w in map.highWalls) {
      canvas
        ..drawRect(r(w), _wall)
        ..drawRect(r(w), _wallEdge..strokeWidth = line);
    }

    // 내 표시: 시야 부채꼴 + 화살표(확대해도 같은 크기).
    final reach = 30 / zoom;
    canvas.drawPath(
      Path()
        ..moveTo(me.dx, me.dy)
        ..arcTo(
          Rect.fromCircle(center: me, radius: reach),
          p.angle - 0.5,
          1.0,
          false,
        )
        ..close(),
      _view,
    );
    final s = 6 / zoom;
    final arrow = Path()
      ..moveTo(s * 1.3, 0)
      ..lineTo(-s, s * 0.85)
      ..lineTo(-s * 0.45, 0)
      ..lineTo(-s, -s * 0.85)
      ..close();
    canvas
      ..save()
      ..translate(me.dx, me.dy)
      ..rotate(p.angle)
      ..drawPath(arrow, _me)
      ..drawPath(arrow, _meEdge..strokeWidth = line)
      ..restore()
      ..restore();
    if (rotating) canvas.drawCircle(c, side / 2, _ring);
  }
}
