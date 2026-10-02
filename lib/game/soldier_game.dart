import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../rules/balance.dart';
import '../rules/movement.dart';
import 'components/compass.dart';
import 'components/player.dart';
import 'components/test_map.dart';
import 'components/touch_controls.dart';

class SoldierGame extends FlameGame with RiverpodGameMixin, KeyboardEvents {
  SoldierGame({this.sensitivity = defaultSensitivity});

  /// 시점 감도 1~10.
  final double sensitivity;

  late final TestMap map;
  late final Player player;
  late final Compass compass;

  final _keys = <LogicalKeyboardKey>{};

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    map = TestMap();
    player = Player(
      position: Vector2(TestMap.spawn.x, TestMap.spawn.y),
      angle: -pi / 2, // 북쪽(맵 위쪽)을 보고 시작
      walls: map.boxes,
    );
    await world.addAll([map, player]);

    // 플레이어가 화면 가로 중앙, 세로 66% 지점.
    camera.viewfinder.anchor = const Anchor(0.5, 0.66);
    compass = Compass(position: Vector2(44, 44));
    await camera.viewport.addAll([
      TouchControls(
        onMove: (f, s) => player
          ..forward = f
          ..strafe = s,
        onTurn: turnBy,
      ),
      compass,
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
    player.angle += keyTurn * debugKeyTurnSpeed * dt;
    super.update(dt);
    _syncCamera();
  }

  /// 정면이 화면 위가 되도록 카메라를 돌린다.
  /// 화면 위쪽 = 월드 (sin θ, −cos θ)이므로 θ = 플레이어 각도 + π/2.
  void _syncCamera() {
    camera.viewfinder
      ..position = player.position
      ..angle = player.angle + pi / 2;
    compass.angle = -camera.viewfinder.angle;
  }

  static final _moveKeys = {
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
  };

  /// 웹 디버그 키: WASD 이동, ←→ 회전.
  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (!_moveKeys.contains(event.logicalKey)) return KeyEventResult.ignored;
    _keys
      ..clear()
      ..addAll(keysPressed);
    double axis(LogicalKeyboardKey plus, LogicalKeyboardKey minus) =>
        (_keys.contains(plus) ? 1.0 : 0.0) -
        (_keys.contains(minus) ? 1.0 : 0.0);
    player
      ..forward = axis(LogicalKeyboardKey.keyW, LogicalKeyboardKey.keyS)
      ..strafe = axis(LogicalKeyboardKey.keyD, LogicalKeyboardKey.keyA);
    return KeyEventResult.handled;
  }
}
