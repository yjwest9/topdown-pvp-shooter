import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../rules/aim.dart';
import '../rules/balance.dart';
import '../rules/combat.dart';
import '../rules/movement.dart';
import 'components/bullet.dart';
import 'components/compass.dart';
import 'components/fire_button.dart';
import 'components/match_hud.dart';
import 'components/player.dart';
import 'components/remote_player.dart';
import 'components/round_button.dart';
import 'components/target_dummy.dart';
import 'components/test_map.dart';
import 'components/touch_controls.dart';
import 'components/weapon_hud.dart';
import 'net/match_sync.dart';

class SoldierGame extends FlameGame with RiverpodGameMixin, KeyboardEvents {
  SoldierGame({
    this.sensitivity = defaultSensitivity,
    Random? random,
    this.match,
  }) : random = random ?? Random();

  /// null이면 오프라인 훈련소(표적 있음). 있으면 1대1(표적 없음).
  final MatchSync? match;

  /// 시점 감도 1~10.
  final double sensitivity;

  /// 탄 퍼짐·미스·크리 랜덤. 테스트는 Random(seed)를 넣는다.
  final Random random;

  /// 무기별 발사 방식. 저장과 설정 화면은 나중.
  final fireModes = {for (final w in weapons) w.id: w.fireMode};

  /// 사격 버튼을 누르고 있음(터치).
  bool fireButtonHeld = false;

  late final TestMap map;
  late final Player player;
  late final Compass compass;
  late final TextComponent stanceLabel;
  late final List<TargetDummy> dummies;

  final _keys = <LogicalKeyboardKey>{};
  bool _touchRun = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    map = TestMap();
    player = Player(
      position: Vector2(_spawn.x, _spawn.y),
      angle: _spawnAngle,
      highWalls: map.highWalls,
      lowCrates: map.lowCrates,
    );
    dummies = [
      if (match == null)
        for (final d in TestMap.dummySpots)
          TargetDummy(
            position: Vector2(d.pos.x, d.pos.y),
            crouching: d.crouching,
            onCrate: d.onCrate,
          ),
    ];
    await world.addAll([map, ...dummies, player]);
    if (match != null) {
      await add(match!);
      await camera.viewport.add(MatchHud(match!));
    }

    // 플레이어가 화면 가로 중앙, 세로 66% 지점.
    camera.viewfinder.anchor = const Anchor(0.5, 0.66);
    compass = Compass(position: Vector2(44, 44));
    stanceLabel = TextComponent(
      position: Vector2(16, 84),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFE8B33A),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    // 오른쪽 아래. 맨 아래 오른쪽은 사격 버튼.
    final fireButton = FireButton(
      visible: () => _fireMode == FireMode.manual,
      onFire: (held) => fireButtonHeld = held,
    );
    final buttons = <PositionComponent>[
      HudButtonComponent(
        button: RoundButton(label: 'JUMP', active: () => player.body.airborne),
        margin: const EdgeInsets.only(right: 122, bottom: 92),
        onPressed: () => player.body.jump(),
      ),
      HudButtonComponent(
        button: RoundButton(
          label: 'DUCK',
          radius: 28,
          active: () => player.body.crouching,
        ),
        margin: const EdgeInsets.only(right: 42, bottom: 148),
        onPressed: () => player.body.toggleCrouch(),
      ),
      HudButtonComponent(
        button: RoundButton(
          label: 'RELOAD',
          radius: 24,
          active: () => player.weapon.reloading,
        ),
        margin: const EdgeInsets.only(right: 128, bottom: 176),
        onPressed: () => player.weapon.reload(),
      ),
      // 오른쪽 위 무기 슬롯. 근접무기 슬롯은 나중에 왼쪽에 추가.
      for (final (i, primary) in [(1, true), (0, false)])
        WeaponSlot(
          label: primary ? 'PRIMARY' : 'SECONDARY',
          index: i,
          weapon: () => primary ? player.primary : player.secondary,
          active: () => player.usingPrimary == primary,
          fireMode: () =>
              fireModes[(primary ? player.primary : player.secondary)
                  .weapon
                  .id]!,
          onTap: () => player.selectSlot(primary: primary),
        ),
    ];
    await camera.viewport.addAll([
      TouchControls(
        onMove: (f, s, run) {
          player
            ..forward = f
            ..strafe = s;
          _touchRun = run;
          _syncRun();
        },
        onTurn: turnBy,
        buttons: buttons,
        isRunning: () => player.body.running,
        fireButton: fireButton,
      ),
      ...buttons,
      fireButton,
      compass,
      stanceLabel,
    ]);
    _syncCamera();
  }

  /// 오른쪽 화면 가로 드래그 [dragDx] px만큼 회전.
  void turnBy(double dragDx) => player.angle = turn(
    player.angle,
    dragDx: dragDx,
    sensitivity: sensitivity,
  );

  // 방장(A팀)·훈련소는 남쪽에서 북쪽을, 참가자(B팀)는 북쪽에서 남쪽을 보고 시작. 진영 맵은 나중.
  bool get _south => match?.isHost ?? true;
  Vec get _spawn => _south ? TestMap.spawn : TestMap.spawnNorth;
  double get _spawnAngle => _south ? -pi / 2 : pi / 2;

  /// 내 진영 스폰으로 되돌린다(부활).
  void respawnPlayer() =>
      player.respawnAt(Vector2(_spawn.x, _spawn.y), _spawnAngle);

  @override
  void update(double dt) {
    // 죽어 있는 동안은 움직이거나 쏘지 못한다.
    if (match?.isDead ?? false) {
      player
        ..forward = 0
        ..strafe = 0
        ..wantsRun = false;
    }
    final keyTurn =
        (_keys.contains(LogicalKeyboardKey.arrowRight) ? 1 : 0) -
        (_keys.contains(LogicalKeyboardKey.arrowLeft) ? 1 : 0);
    player.angle +=
        keyTurn * debugKeyTurnSpeed * (sensitivity / defaultSensitivity) * dt;
    // 이동 전에 정해야 달리던 중이면 이번 프레임부터 걷는다.
    player.firing = !(match?.isDead ?? false) && _wantsToFire();
    super.update(dt);
    _updateFiring(dt);
    _syncCamera();
    stanceLabel.text = _stanceText();
  }

  /// 총알·자동 사격 대상: 살아 있는 표적 + 살아 있는 상대.
  List<HitTarget> get hitTargets => [
    for (final d in dummies)
      if (!d.dead)
        (
          key: d,
          body: d.coverBody,
          stance: d.stance,
          protected: false,
          onHit: (h, _) => d.takeDamage(h.damage),
        ),
    for (final r in match?.remotes.values ?? const <RemotePlayer>[])
      if (r.targetable)
        (
          key: r,
          body: r.coverBody,
          stance: r.stance,
          protected: r.protected,
          onHit: (h, w) => match!.hit(r.uid, h, w),
        ),
  ];

  FireMode get _fireMode => fireModes[player.weapon.weapon.id]!;

  bool get _triggerHeld =>
      fireButtonHeld || _keys.contains(LogicalKeyboardKey.arrowUp);

  /// 수동: 버튼(또는 ↑)을 누르는 동안. 자동: 자동 사격 대상이 있거나 ↑.
  /// 탄이 없거나 재장전 중이면 false(달리기를 끊지 않게).
  bool _wantsToFire() {
    final w = player.weapon;
    if (w.ammo == 0 || w.reloading) return false;
    if (_triggerHeld) return true;
    if (_fireMode != FireMode.auto) return false;
    return autoFireTarget(
          shooter: player.coverBody,
          aim: player.angle,
          range: w.weapon.range,
          targets: [for (final t in hitTargets) t.body],
          highWalls: map.highWalls,
          lowCrates: map.lowCrates,
        ) !=
        null;
  }

  /// 연사 간격·탄약은 WeaponState가 막는다. 달리는 중엔 못 쏜다.
  void _updateFiring(double dt) {
    final w = player.weapon..tick(dt);
    if (!player.firing || !canFire(player.stance) || !w.tryFire()) return;
    final angles = shotAngles(
      w.weapon,
      player.stance,
      aim: player.angle,
      roll: random.nextDouble(),
    );
    final muzzle =
        player.position +
        Vector2(cos(player.angle), sin(player.angle)) * (playerRadius + 10);
    world.addAll([
      for (final a in angles)
        Bullet(
          position: muzzle.clone(),
          angle: a,
          weapon: w.weapon,
          shooter: player.coverBody,
        ),
    ]);
    for (final a in angles) {
      match?.sendShot(muzzle, a, w.weapon.id);
    }
  }

  String _stanceText() {
    final b = player.body;
    if (b.airborne) return 'JUMP';
    if (b.onCrate) return b.crouching ? 'ON CRATE · CROUCH' : 'ON CRATE';
    if (b.running) return 'RUN';
    if (b.crouching) return 'CROUCH';
    return 'STAND';
  }

  /// 정면이 화면 위가 되도록 카메라를 돌린다.
  /// 화면 위쪽 = 월드 (sin θ, −cos θ)이므로 θ = 플레이어 각도 + π/2.
  void _syncCamera() {
    camera.viewfinder
      ..position = player.position
      ..angle = player.angle + pi / 2;
    compass.angle = -camera.viewfinder.angle;
  }

  bool get _shiftHeld =>
      _keys.contains(LogicalKeyboardKey.shiftLeft) ||
      _keys.contains(LogicalKeyboardKey.shiftRight);

  void _syncRun() => player.wantsRun = _touchRun || _shiftHeld;

  static final _gameKeys = {
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.keyC,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.keyQ,
    LogicalKeyboardKey.keyR,
    ..._weaponKeys,
  };

  /// 1~9, 0 = 주무기 10종(weapons 앞 10개).
  static final _weaponKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
    LogicalKeyboardKey.digit0,
  ];

  /// 웹 디버그 키: WASD 이동, ←→ 회전, Space 점프, C/Ctrl 앉기, Shift 달리기,
  /// ↑ 사격, 1~9·0 주무기 선택, Q 주·보조 교체, R 재장전.
  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final key = event.logicalKey;
    if (!_gameKeys.contains(key)) return KeyEventResult.ignored;
    _keys
      ..clear()
      ..addAll(keysPressed);

    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.space) player.body.jump();
      if (key == LogicalKeyboardKey.keyC ||
          key == LogicalKeyboardKey.controlLeft ||
          key == LogicalKeyboardKey.controlRight) {
        player.body.toggleCrouch();
      }
      if (key == LogicalKeyboardKey.keyQ) player.swapWeapon();
      if (key == LogicalKeyboardKey.keyR) player.weapon.reload();
      final slot = _weaponKeys.indexOf(key);
      if (slot >= 0) player.selectPrimary(weapons[slot]);
    }

    double axis(LogicalKeyboardKey plus, LogicalKeyboardKey minus) =>
        (_keys.contains(plus) ? 1.0 : 0.0) -
        (_keys.contains(minus) ? 1.0 : 0.0);
    player
      ..forward = axis(LogicalKeyboardKey.keyW, LogicalKeyboardKey.keyS)
      ..strafe = axis(LogicalKeyboardKey.keyD, LogicalKeyboardKey.keyA);
    _syncRun();
    return KeyEventResult.handled;
  }
}
