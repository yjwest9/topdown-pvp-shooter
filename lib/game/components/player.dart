import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../rules/aim.dart';
import '../../rules/balance.dart';
import '../../rules/cover.dart';
import '../../rules/movement.dart';
import '../../rules/stance.dart';
import '../../rules/weapon_state.dart';

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

  /// 조이스틱 바깥 원 또는 Shift. 실제로는 앞쪽(±45°)으로 밀 때만 달린다.
  bool wantsRun = false;

  /// 이번 프레임에 쏘려고 함. 달리던 중이면 걷기로 바뀐다.
  bool firing = false;

  /// 지난 프레임 실제 이동 속도(px/s). 서기/걷기 판정용.
  double speed = 0;

  /// 부활 보호 중: 반투명하게 깜빡인다.
  bool blinking = false;
  double _t = 0;

  /// 부활: 자리·방향을 옮기고 자세를 처음 상태로.
  void respawnAt(Vector2 at, double facing) {
    position.setFrom(at);
    angle = facing;
    body
      ..airTime = 0
      ..jumpCooldownLeft = 0
      ..crouching = false
      ..running = false
      ..onCrate = false;
  }

  Stance get stance => body.stance(speed);

  CoverBody get coverBody => (
    pos: (x: position.x, y: position.y),
    crouching: body.crouching,
    airborne: body.airborne,
    onCrate: body.onCrate,
  );

  /// 가진 무기마다 탄약 상태를 기억한다(바꿨다 돌아와도 장전 안 됨).
  final _owned = <WeaponStats, WeaponState>{};
  WeaponState _own(WeaponStats w) =>
      _owned.putIfAbsent(w, () => WeaponState(w));

  /// 로드아웃: 주무기 + 보조(권총).
  late WeaponState primary = _own(rifleStandard);
  late final WeaponState secondary = _own(pistol);
  bool usingPrimary = true;

  WeaponState get weapon => usingPrimary ? primary : secondary;

  /// 슬롯 버튼. 다른 슬롯으로 바꾸면 하던 재장전은 취소.
  void selectSlot({required bool primary}) {
    if (primary == usingPrimary) return;
    weapon.cancelReload();
    usingPrimary = primary;
  }

  /// Q 키: 주·보조 교체.
  void swapWeapon() => selectSlot(primary: !usingPrimary);

  /// 주무기를 [w]로 바꾸고 든다(웹 디버그 키 1~0).
  void selectPrimary(WeaponStats w) {
    weapon.cancelReload();
    primary = _own(w);
    usingPrimary = true;
  }

  static final _body = Paint()..color = const Color(0xFF4FA3E0);
  static final _muzzle = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..strokeWidth = 4;
  static final _shadow = Paint()..color = const Color(0x59000000);
  static final _faded = Paint()..color = const Color(0x59000000);
  static final _aimLine = Paint()
    ..color = const Color(0x47E8B33A)
    ..strokeWidth = 1.5;
  static final _spreadLine = Paint()
    ..color = const Color(0x38E8B33A)
    ..strokeWidth = 1;
  static final _crouchRing = Paint()
    ..color = const Color(0x99E3E6D8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void update(double dt) {
    if (dt <= 0) return;
    _t += dt;
    final input = sqrt(forward * forward + strafe * strafe);
    body.updateRunning(
      wantsRun: wantsRun && runDirectionOk(forward: forward, strafe: strafe),
      inputMagnitude: input,
      firing: firing,
    );

    final from = (x: position.x, y: position.y);
    var to = from;
    if (input > 0) {
      final d = moveDelta(
        angle: angle,
        forward: forward,
        strafe: strafe,
        distance:
            walkSpeed * body.moveSpeedMultiplier * weapon.weapon.moveSpeed * dt,
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
  double get lift {
    final jump = body.airborne
        ? sin(pi * (1 - body.airTime / jumpDuration).clamp(0, 1))
        : 0.0;
    return jump + (body.onCrate ? 0.5 : 0);
  }

  @override
  void render(Canvas canvas) {
    const c = Offset(playerRadius, playerRadius);
    // 점프 최대 1.35배, 상자 위 1.175배, 앉으면 ×0.82.
    final scale = (1 + 0.35 * lift) * (body.crouching ? 0.82 : 1);
    _renderAim(canvas, c);
    final blink = blinking && (_t * 8).floor().isEven;
    if (blink) canvas.saveLayer(null, _faded);

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
    if (blink) canvas.restore();
  }

  /// 정면 점선(사거리까지) + 현재 퍼짐 폭 두 줄. 로컬 +x = 정면.
  void _renderAim(Canvas canvas, Offset c) {
    final range = weapon.weapon.range;
    for (var d = 30.0; d < range; d += 14) {
      canvas.drawLine(
        c + Offset(d, 0),
        c + Offset(min(d + 6, range), 0),
        _aimLine,
      );
    }
    final h = spreadHalfAngle(weapon.weapon, stance);
    for (final a in [-h, h]) {
      final dir = Offset(cos(a), sin(a));
      canvas.drawLine(c + dir * 30, c + dir * range * 0.93, _spreadLine);
    }
  }
}
