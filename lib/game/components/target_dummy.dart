import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../rules/balance.dart';
import '../../rules/cover.dart';

/// 훈련용 표적. 기본 병사 능력치, 움직이지 않음, 죽으면 같은 자리에서 부활.
class TargetDummy extends PositionComponent {
  TargetDummy({
    required super.position,
    this.crouching = false,
    this.onCrate = false,
  }) : super(size: Vector2.all(playerRadius * 2), anchor: Anchor.center);

  final bool crouching;
  final bool onCrate;

  static const stats = basicSoldier;
  double hp = stats.hp.toDouble();
  double respawnLeft = 0;

  bool get dead => respawnLeft > 0;
  Stance get stance => crouching ? Stance.crouching : Stance.standing;
  CoverBody get coverBody => (
    pos: (x: position.x, y: position.y),
    crouching: crouching,
    airborne: false,
    onCrate: onCrate,
  );

  void takeDamage(double damage) {
    hp -= damage;
    if (hp > 0) return;
    hp = 0;
    respawnLeft = dummyRespawnTime;
  }

  @override
  void update(double dt) {
    if (!dead) return;
    respawnLeft -= dt;
    if (respawnLeft <= 0) {
      respawnLeft = 0;
      hp = stats.hp.toDouble();
    }
  }

  static final _body = Paint()..color = const Color(0xFFE0563F);
  static final _ghost = Paint()..color = const Color(0x33E0563F);
  static final _hpBack = Paint()
    ..color = const Color(0x55000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  static final _hp = Paint()
    ..color = const Color(0xFFE3E6D8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  static final _crouchRing = Paint()
    ..color = const Color(0x99E3E6D8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void render(Canvas canvas) {
    const c = Offset(playerRadius, playerRadius);
    final scale = (onCrate ? 1.175 : 1.0) * (crouching ? 0.82 : 1.0);
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..scale(scale);
    if (dead) {
      canvas
        ..drawCircle(Offset.zero, playerRadius, _ghost)
        ..restore();
      return;
    }
    canvas.drawCircle(Offset.zero, playerRadius, _body);
    if (crouching) {
      canvas.drawCircle(Offset.zero, playerRadius * 1.25, _crouchRing);
    }
    // 체력 링: 회전 시점에서도 읽히도록 막대 대신 원호.
    final ring = Rect.fromCircle(center: Offset.zero, radius: playerRadius + 6);
    canvas
      ..drawArc(ring, 0, 2 * pi, false, _hpBack)
      ..drawArc(ring, -pi / 2, 2 * pi * hp / stats.hp, false, _hp)
      ..restore();
  }
}
