import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart' show FontWeight, TextStyle;

import '../../rules/minimap_view.dart';
import '../soldier_game.dart';

/// 왼쪽 위 미니맵. 내 진영은 늘 파란색, 상대는 빨간색.
/// 두 가지 모드(눌러서 전환, 선택은 기기에 저장):
/// - 회전: 내 주변이 확대되고 내가 보는 쪽이 위(발로란트식).
/// - 고정: 맵 전체. 내 진영이 늘 아래(B팀은 180도 뒤집어서 A팀과 똑같이 보인다).
/// 벽·상자, 두 진영 영역, 내 위치와 방향만. 상대는 그리지 않는다.
class Minimap extends PositionComponent
    with HasGameReference<SoldierGame>, TapCallbacks {
  Minimap({required super.position, this.mapWidth = 90});

  /// 미니맵 가로 길이. 세로는 맵 비율대로.
  final double mapWidth;

  static final _back = Paint()..color = const Color(0x99000000);
  static final _frame = Paint()
    ..color = const Color(0x66E3E6D8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  static final _wall = Paint()..color = const Color(0xFF8A8F96);
  static final _crate = Paint()..color = const Color(0xFFB08850);
  static final _mine = Paint()..color = const Color(0x554FA3E0);
  static final _enemy = Paint()..color = const Color(0x55E0563F);
  static final _me = Paint()..color = const Color(0xFFFFFFFF);
  static final _label = TextPaint(
    style: const TextStyle(
      color: Color(0xFFE8B33A),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    ),
  );

  @override
  void onMount() {
    super.onMount();
    final map = game.map;
    size = Vector2(mapWidth, mapWidth * map.height / map.width);
  }

  @override
  void onTapUp(TapUpEvent event) => game.toggleMinimapMode();

  @override
  void render(Canvas canvas) {
    final map = game.map;
    final k = mapWidth / map.width;
    final myTeam = game.match!.team;
    final rotating = game.minimapRotates;
    final p = game.player;
    final me = Offset(p.position.x * k, p.position.y * k);
    final zoom = rotating ? minimapZoom : 1.0;
    Rect r(({double left, double top, double right, double bottom}) b) =>
        Rect.fromLTRB(b.left * k, b.top * k, b.right * k, b.bottom * k);

    canvas
      ..drawRect(size.toRect(), _back)
      ..save()
      ..clipRect(size.toRect())
      ..translate(size.x / 2, size.y / 2)
      ..rotate(
        minimapRotation(
          rotating: rotating,
          teamA: game.isTeamA,
          playerAngle: p.angle,
        ),
      )
      ..scale(zoom);
    // 회전 모드는 내가 중심, 고정 모드는 맵 전체가 중심.
    final center = rotating ? me : Offset(size.x / 2, size.y / 2);
    canvas.translate(-center.dx, -center.dy);

    for (final b in map.bases) {
      canvas.drawRect(r(b.area), b.team == myTeam ? _mine : _enemy);
    }
    for (final w in map.highWalls) {
      canvas.drawRect(r(w), _wall);
    }
    for (final c in map.lowCrates) {
      canvas.drawRect(r(c), _crate);
    }
    // 확대해도 내 표시는 같은 크기.
    canvas
      ..drawLine(
        me,
        me + Offset(cos(p.angle), sin(p.angle)) * (7 / zoom),
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..strokeWidth = 1.5 / zoom,
      )
      ..drawCircle(me, 2.5 / zoom, _me)
      ..restore()
      ..drawRect(size.toRect(), _frame);
    _label.render(
      canvas,
      rotating ? 'ROTATE' : 'FIXED',
      Vector2(0, size.y + 2),
    );
  }
}
