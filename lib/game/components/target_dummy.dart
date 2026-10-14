import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../rules/appearance.dart';
import '../../rules/balance.dart';
import '../../rules/cover.dart';
import '../game_art.dart';
import '../soldier_game.dart';

/// 훈련용 표적. 기본 병사 능력치, 움직이지 않음, 죽으면 같은 자리에서 부활.
class TargetDummy extends PositionComponent with HasGameReference<SoldierGame> {
  TargetDummy({
    required super.position,
    this.crouching = false,
    this.onCrate = false,
  }) : super(
         size: Vector2.all(playerRadius * 2),
         anchor: Anchor.center,
         // 플레이어가 시작하는 남쪽에서 보면 정면(북쪽)을 향해 서 있다 → 남쪽을 본다.
         angle: pi / 2,
       );

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

  static final _teamFill = Paint()..color = const Color(0x55E0563F);
  static final _teamRing = Paint()
    ..color = const Color(0xFFE0563F)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
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
    final scale =
        (onCrate ? 1.175 : 1.0) * (crouching ? GameArt.crouchScale : 1.0);
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
    canvas
      ..drawCircle(Offset.zero, playerRadius, _teamFill)
      ..drawCircle(Offset.zero, playerRadius, _teamRing);
    game.art.drawSoldier(canvas, stats.id, Pose.stand);
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
