import 'dart:ui';

import 'package:flame/components.dart';

import '../../rules/balance.dart';
import '../../rules/movement.dart';

/// [angle]은 바라보는 방향(rad, 0 = +x). 몸 그림도 이 각도로 회전한다.
class Player extends PositionComponent {
  Player({required super.position, required super.angle, required this.walls})
    : super(size: Vector2.all(playerRadius * 2), anchor: Anchor.center);

  final List<Box> walls;

  /// 정면 기준 입력. 앞+, 오른쪽+. 길이 1 이하(넘으면 잘림).
  double forward = 0;
  double strafe = 0;

  static final _body = Paint()..color = const Color(0xFF4FA3E0);
  static final _muzzle = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..strokeWidth = 4;

  @override
  void update(double dt) {
    if (forward == 0 && strafe == 0) return;
    final speed = walkSpeed * stanceStats[Stance.walking]!.speed;
    final d = moveDelta(
      angle: angle,
      forward: forward,
      strafe: strafe,
      distance: speed * dt,
    );
    final p = slide((x: position.x, y: position.y), d, playerRadius, walls);
    position.setValues(p.x, p.y);
  }

  @override
  void render(Canvas canvas) {
    const c = Offset(playerRadius, playerRadius);
    canvas
      ..drawCircle(c, playerRadius, _body)
      ..drawLine(c, const Offset(playerRadius * 2 + 10, playerRadius), _muzzle);
  }
}
