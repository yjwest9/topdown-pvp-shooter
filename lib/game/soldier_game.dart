import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../rules/balance.dart';
import '../rules/movement.dart';
import 'components/compass.dart';
import 'components/player.dart';
import 'components/round_button.dart';
import 'components/test_map.dart';
import 'components/touch_controls.dart';

class SoldierGame extends FlameGame with RiverpodGameMixin, KeyboardEvents {
  SoldierGame({this.sensitivity = defaultSensitivity});

  /// 시점 감도 1~10.
  final double sensitivity;

  late final TestMap map;
  late final Player player;
  late final Compass compass;
  late final TextComponent stanceLabel;

  final _keys = <LogicalKeyboardKey>{};
  bool _touchRun = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    map = TestMap();
    player = Player(
      position: Vector2(TestMap.spawn.x, TestMap.spawn.y),
      angle: -pi / 2, // 북쪽(맵 위쪽)을 보고 시작
      highWalls: map.highWalls,
      lowCrates: map.lowCrates,
    );
    await world.addAll([map, player]);

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
    // 오른쪽 아래. 맨 아래 오른쪽 자리는 나중에 사격 버튼용으로 비워 둔다.
    final buttons = [
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
      ),
      ...buttons,
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

  @override
  void update(double dt) {
    final keyTurn =
        (_keys.contains(LogicalKeyboardKey.arrowRight) ? 1 : 0) -
        (_keys.contains(LogicalKeyboardKey.arrowLeft) ? 1 : 0);
    player.angle +=
        keyTurn * debugKeyTurnSpeed * (sensitivity / defaultSensitivity) * dt;
    super.update(dt);
    _syncCamera();
    stanceLabel.text = _stanceText();
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
  };

  /// 웹 디버그 키: WASD 이동, ←→ 회전, Space 점프, C/Ctrl 앉기, Shift 달리기.
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
