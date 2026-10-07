import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/models/room.dart';
import '../soldier_game.dart';

/// 왼쪽 위 미니맵. 회전하지 않고 북쪽이 위(나침반과 같은 기준).
/// 벽·상자, 두 진영 영역, 내 위치와 방향만. 상대는 그리지 않는다.
class Minimap extends PositionComponent with HasGameReference<SoldierGame> {
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
  static final _baseA = Paint()..color = const Color(0x554FA3E0);
  static final _baseB = Paint()..color = const Color(0x55E0563F);
  static final _me = Paint()..color = const Color(0xFFFFFFFF);
  static final _facing = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..strokeWidth = 1.5;

  @override
  void onMount() {
    super.onMount();
    final map = game.map;
    size = Vector2(mapWidth, mapWidth * map.height / map.width);
  }

  @override
  void render(Canvas canvas) {
    final map = game.map;
    final k = mapWidth / map.width;
    Rect r(({double left, double top, double right, double bottom}) b) =>
        Rect.fromLTRB(b.left * k, b.top * k, b.right * k, b.bottom * k);

    canvas.drawRect(size.toRect(), _back);
    for (final b in map.bases) {
      canvas.drawRect(r(b.area), b.team == RoomMeta.teamA ? _baseA : _baseB);
    }
    for (final w in map.highWalls) {
      canvas.drawRect(r(w), _wall);
    }
    for (final c in map.lowCrates) {
      canvas.drawRect(r(c), _crate);
    }

    final p = game.player;
    final me = Offset(p.position.x * k, p.position.y * k);
    canvas
      ..drawLine(me, me + Offset(cos(p.angle), sin(p.angle)) * 7, _facing)
      ..drawCircle(me, 2.5, _me)
      ..drawRect(size.toRect(), _frame);
  }
}
