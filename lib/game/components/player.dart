import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../rules/balance.dart';
import '../../rules/movement.dart';
import '../../rules/stance.dart';

/// [angle]은 바라보는 방향(rad, 0 = +x). 몸 그림도 이 각도로 회전한다.
class Player extends PositionComponent {
  Player({
    required super.position,
    required super.angle,
    required this.highWalls,
    required this.lowCrates,
  }) : super(size: Vector2.all(playerRadius * 2), anchor: Anchor.center);

  final List<Box> highWalls;
  final List<Box> lowCrates;
  late final _allBlocks = [...highWalls, ...lowCrates];

  final body = StanceState();

  /// 정면 기준 입력. 앞+, 오른쪽+. 길이 1 이하(넘으면 잘림).
  double forward = 0;
  double strafe = 0;

  /// 조이스틱 바깥 원 또는 Shift.
  bool wantsRun = false;

  /// 지난 프레임 실제 이동 속도(px/s). 서기/걷기 판정용.
  double speed = 0;

  Stance get stance => body.stance(speed);

  static final _body = Paint()..color = const Color(0xFF4FA3E0);
  static final _muzzle = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..strokeWidth = 4;
  static final _shadow = Paint()..color = const Color(0x59000000);
  static final _crouchRing = Paint()
    ..color = const Color(0x99E3E6D8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void update(double dt) {
    if (dt <= 0) return;
    final input = sqrt(forward * forward + strafe * strafe);
    body.updateRunning(wantsRun: wantsRun, inputMagnitude: input);

    final from = (x: position.x, y: position.y);
    var to = from;
    if (input > 0) {
      final d = moveDelta(
        angle: angle,
        forward: forward,
        strafe: strafe,
        distance: walkSpeed * body.moveSpeedMultiplier * dt,
      );
      final walls = body.ignoresLowCrates ? highWalls : _allBlocks;
      to = slide(from, d, playerRadius, walls);
      position.setValues(to.x, to.y);
    }
    speed = sqrt(pow(to.x - from.x, 2) + pow(to.y - from.y, 2)) / dt;

    body.tick(
      dt,
      centerInLowCrate: lowCrates.any((c) => pointInBox(to, c)),
      overlapsLowCrate: lowCrates.any(
        (c) => circleOverlapsBox(to, playerRadius, c),
      ),
    );
  }

  /// 점프 중 0→1→0, 상자 위 +0.5 (decisions 시안과 같은 연출).
  double get _lift {
    final jump = body.airborne
        ? sin(pi * (1 - body.airTime / jumpDuration).clamp(0, 1))
        : 0.0;
    return jump + (body.onCrate ? 0.5 : 0);
  }

  @override
  void render(Canvas canvas) {
    const c = Offset(playerRadius, playerRadius);
    final lift = _lift;
    // 점프 최대 1.35배, 상자 위 1.175배, 앉으면 ×0.82.
    final scale = (1 + 0.35 * lift) * (body.crouching ? 0.82 : 1);

    if (lift > 0) {
      // 그림자는 화면 오른쪽 아래로. 플레이어는 늘 화면 위를 보므로
      // 로컬 +x = 화면 위, +y = 화면 오른쪽 → 화면 (6, 8)은 로컬 (−8, 6).
      canvas.drawCircle(
        c + Offset(-8 * lift, 6 * lift),
        playerRadius * (1 - 0.2 * lift),
        _shadow,
      );
    }

    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..scale(scale)
      ..drawCircle(Offset.zero, playerRadius, _body)
      ..drawLine(Offset.zero, const Offset(playerRadius + 10, 0), _muzzle);
    if (body.crouching) {
      canvas.drawCircle(Offset.zero, playerRadius * 1.25, _crouchRing);
    }
    canvas.restore();
  }
}
