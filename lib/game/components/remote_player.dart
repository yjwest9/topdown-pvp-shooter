import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/models/room.dart';
import '../../rules/balance.dart';
import '../../rules/cover.dart';
import '../net/interpolation.dart';
import '../net/match_sync.dart';
import '../soldier_game.dart';

/// 상대 병사. 받은 상태를 [MatchSync.renderTime](서버 시간 − 100ms)에 맞춰 보간해서 그린다.
class RemotePlayer extends PositionComponent
    with HasGameReference<SoldierGame> {
  RemotePlayer({required this.sync, required this.uid})
    : super(size: Vector2.all(playerRadius * 2), anchor: Anchor.center);

  final MatchSync sync;
  final String uid;
  final _buffer = <NetState>[];
  double _t = 0;

  /// 지금 그리는(보간된) 상태. 아직 받은 게 없으면 null.
  NetState? state;

  NetHp? get hp => sync.hp[uid];
  bool get dead => (hp?.value ?? 1) <= 0;
  bool get protected => sync.isProtected(hp);

  /// 맞힐 수 있음: 받은 상태가 있고 살아 있음. 숨었는지는 상자 판정이 따로 막는다.
  bool get targetable => state != null && !dead;

  /// 같은 상태가 여러 번 와도(내가 쓸 때도 states 전체가 옴) 새 것만 쌓는다.
  void push(NetState s) {
    if (_buffer.isNotEmpty && s.t <= _buffer.last.t) return;
    _buffer.add(s);
    if (_buffer.length > 30) _buffer.removeAt(0);
  }

  Stance get stance => Stance.values.byName(state?.stance ?? 'standing');

  CoverBody get coverBody {
    final airborne = stance == Stance.jumping;
    return (
      pos: (x: position.x, y: position.y),
      crouching: stance == Stance.crouching,
      airborne: airborne,
      onCrate: !airborne && (state?.up ?? 0) >= 0.5,
    );
  }

  /// 죽었거나 낮은 상자 뒤에 앉아 숨었으면 나에게 안 보인다.
  bool get visible =>
      targetable &&
      !hiddenBehindLowCover(
        coverBody,
        game.player.coverBody,
        game.map.lowCrates,
      );

  @override
  void update(double dt) {
    _t += dt;
    final s = sample(_buffer, sync.renderTime);
    if (s == null) return;
    state = s;
    position.setValues(s.x, s.y);
    angle = s.a;
  }

  static final _body = Paint()..color = const Color(0xFFE0563F);
  static final _muzzle = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..strokeWidth = 4;
  static final _crouchRing = Paint()
    ..color = const Color(0x99E3E6D8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _barBack = Paint()..color = const Color(0x99000000);
  static final _bar = Paint()..color = const Color(0xFFE0563F);
  static final _faded = Paint()..color = const Color(0x59000000);

  // ponytail: 점프 그림자는 생략(상대 몸 크기로만 표시). 회전 시점에서 그림자 방향을 맞추려면 카메라 각도를 받아야 함.
  @override
  void render(Canvas canvas) {
    if (!visible) return;
    final crouching = stance == Stance.crouching;
    // 내 Player와 같은 연출: 점프·상자 위면 커지고, 앉으면 ×0.82.
    final scale = (1 + 0.35 * state!.up) * (crouching ? 0.82 : 1);
    // 부활 보호 중엔 반투명하게 깜빡인다.
    final blink = protected && (_t * 8).floor().isEven;
    if (blink) canvas.saveLayer(null, _faded);
    canvas
      ..save()
      ..translate(playerRadius, playerRadius)
      ..scale(scale)
      ..drawCircle(Offset.zero, playerRadius, _body)
      ..drawLine(Offset.zero, const Offset(playerRadius + 10, 0), _muzzle);
    if (crouching) {
      canvas.drawCircle(Offset.zero, playerRadius * 1.25, _crouchRing);
    }
    canvas.restore();
    if (blink) canvas.restore();
    _renderHpBar(canvas);
  }

  /// 머리 위 체력 바. 카메라 각도만큼 돌려 화면에서 똑바로 보이게.
  void _renderHpBar(Canvas canvas) {
    final ratio = ((hp?.value ?? basicSoldier.hp) / basicSoldier.hp).clamp(
      0.0,
      1.0,
    );
    canvas
      ..save()
      ..translate(playerRadius, playerRadius)
      ..rotate(game.camera.viewfinder.angle - angle);
    const w = 34.0, h = 4.0, y = -playerRadius - 14;
    canvas
      ..drawRect(const Rect.fromLTWH(-w / 2, y, w, h), _barBack)
      ..drawRect(Rect.fromLTWH(-w / 2, y, w * ratio, h), _bar)
      ..restore();
  }
}
