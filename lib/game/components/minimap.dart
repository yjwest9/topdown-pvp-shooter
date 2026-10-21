import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../../rules/minimap_view.dart';
import '../soldier_game.dart';

/// 왼쪽 위 원형 미니맵(발로란트식). 맵 전체가 원 안에 들어간다. 걸을 수 있는 곳만
/// 반투명 회색으로 그리고 바깥(벽)은 비워서 게임이 비쳐 보인다. 내 표시는 화살표 + 시야.
/// 두 가지 모드(눌러서 전환, 설정에도 있음):
/// - 회전: 원 안에서 맵 전체가 돌아 내가 보는 쪽이 늘 위.
/// - 고정: 맵이 돌지 않는다. 내 진영이 늘 아래(B팀은 180도 뒤집음).
/// 진영은 옅은 파랑(내 쪽)/빨강(상대 쪽). 글자와 상대 위치는 그리지 않는다.
class Minimap extends PositionComponent
    with HasGameReference<SoldierGame>, TapCallbacks {
  Minimap({required super.position}) : super(size: Vector2.all(side));

  /// 미니맵 지름(px).
  static const side = 150.0;

  static final _disc = Paint()..color = const Color(0x40000000);
  static final _ring = Paint()
    ..color = const Color(0x40FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  static final _floor = Paint()..color = const Color(0x99C9CDD3);
  static final _cut = Paint()..blendMode = BlendMode.clear;
  static final _crate = Paint()..color = const Color(0xCC8D939B);
  static final _mine = Paint()..color = const Color(0x554FA3E0);
  static final _enemy = Paint()..color = const Color(0x55E0563F);
  static final _view = Paint()..color = const Color(0x55FFFFFF);
  static final _me = Paint()..color = const Color(0xFF5DE0C8);
  static final _allyDot = Paint()..color = const Color(0xFF4FA3E0);
  static final _meEdge = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;

  @override
  void onTapUp(TapUpEvent event) => game.toggleMinimapMode();

  @override
  void render(Canvas canvas) {
    final map = game.map;
    final myTeam = game.match!.team;
    final p = game.player;
    // 맵에서 가장 먼 걸을 수 있는 곳까지가 원 안에 들어오는 배율.
    final k = (side / 2 - 3) / map.reach;
    final rotation = minimapRotation(
      rotating: game.minimapRotates,
      teamA: game.isTeamA,
      playerAngle: p.angle,
    );
    Rect r(({double left, double top, double right, double bottom}) b) =>
        Rect.fromLTRB(b.left * k, b.top * k, b.right * k, b.bottom * k);
    const c = Offset(side / 2, side / 2);
    final whole = Rect.fromLTWH(0, 0, map.width * k, map.height * k);

    canvas
      ..drawCircle(c, side / 2, _disc)
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(rotation)
      ..translate(-whole.width / 2, -whole.height / 2)
      // 바닥을 칠하고 벽 자리를 지워서 걸을 수 있는 모양만 남긴다.
      ..saveLayer(whole, Paint())
      ..drawRect(whole, _floor);
    for (final w in map.highWalls) {
      canvas.drawRect(r(w), _cut);
    }
    for (final b in map.bases) {
      canvas.drawRect(r(b.area), b.team == myTeam ? _mine : _enemy);
    }
    for (final cr in map.lowCrates) {
      canvas.drawRect(r(cr), _crate);
    }
    canvas.restore(); // saveLayer

    // 내 표시: 시야 부채꼴 + 화살표.
    final me = Offset(p.position.x * k, p.position.y * k);
    canvas.drawPath(
      Path()
        ..moveTo(me.dx, me.dy)
        ..arcTo(
          Rect.fromCircle(center: me, radius: 18),
          p.angle - 0.5,
          1.0,
          false,
        )
        ..close(),
      _view,
    );
    // 아군은 파란 점(2대2). 적은 안 보인다.
    for (final a in game.match!.allies) {
      canvas.drawCircle(
        Offset(a.position.x * k, a.position.y * k),
        3.5,
        _allyDot,
      );
    }
    const s = 5.0;
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
      ..drawPath(arrow, _meEdge)
      ..restore()
      ..restore()
      ..drawCircle(c, side / 2, _ring);
  }
}
