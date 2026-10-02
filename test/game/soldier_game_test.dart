import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/game/soldier_game.dart';
import 'package:topsoldier/rules/balance.dart';

GameTester<SoldierGame> gameTester({double sensitivity = 5}) => GameTester(
  () => SoldierGame(sensitivity: sensitivity),
  createGameWidget: (game) =>
      RiverpodAwareGameWidget(key: GlobalKey(), game: game),
  pumpWidget: (widget, tester) =>
      tester.pumpWidget(ProviderScope(child: widget)),
);

/// 열린 공간(주변에 벽 없음)으로 옮기고 각도를 정한다.
void place(SoldierGame game, double angle) {
  game.player
    ..position = Vector2(700, 1000)
    ..angle = angle;
}

void main() {
  for (final a in [0.0, pi / 2, pi]) {
    gameTester().testGameWidget(
      'forward 1s at angle $a moves (cos a, sin a) x speed',
      verify: (game, tester) async {
        place(game, a);
        game.player.forward = 1;
        game.update(1);
        expect(game.player.position.x, closeTo(700 + cos(a) * walkSpeed, 1e-6));
        expect(
          game.player.position.y,
          closeTo(1000 + sin(a) * walkSpeed, 1e-6),
        );
      },
    );
  }

  gameTester().testGameWidget(
    'drag turn with sensitivity 5',
    verify: (game, tester) async {
      place(game, 0);
      game.turnBy(100);
      expect(game.player.angle, closeTo(0.75, 1e-9));
    },
  );

  gameTester(sensitivity: 10).testGameWidget(
    'drag turn with sensitivity 10 is twice as fast',
    verify: (game, tester) async {
      place(game, 0);
      game.turnBy(100);
      expect(game.player.angle, closeTo(1.5, 1e-9));
    },
  );

  gameTester().testGameWidget(
    'walking into the outer wall does not pass through',
    verify: (game, tester) async {
      place(game, pi / 2); // south, toward the bottom wall
      game.player.forward = 1;
      for (var i = 0; i < 60 * 5; i++) {
        game.update(1 / 60);
      }
      final bottomWallTop = game.map.blocks.map((b) => b.box.top).reduce(max);
      expect(
        game.player.position.y,
        lessThanOrEqualTo(bottomWallTop - playerRadius),
      );
      // 벽 바로 앞까지는 갔다 (중간에 멈춘 게 아님)
      expect(
        game.player.position.y,
        greaterThan(bottomWallTop - playerRadius - 5),
      );
    },
  );

  gameTester().testGameWidget(
    'camera: player at (50%, 66%), facing direction is screen up',
    verify: (game, tester) async {
      place(game, 0.4);
      game.update(0);
      final cam = game.camera;
      final me = cam.localToGlobal(game.player.position);
      final ahead = cam.localToGlobal(
        game.player.position + Vector2(cos(0.4), sin(0.4)) * 100,
      );
      expect(me.x, closeTo(game.size.x * 0.5, 1e-3));
      expect(me.y, closeTo(game.size.y * 0.66, 1e-3));
      expect(ahead.x, closeTo(me.x, 1e-3));
      expect(ahead.y, closeTo(me.y - 100, 1e-3));
    },
  );

  gameTester().testGameWidget(
    'compass needle points to world north on screen',
    verify: (game, tester) async {
      place(game, 0); // facing east -> north is screen left
      game.update(0);
      final north = game.camera.localToGlobal(Vector2(700, 900));
      final me = game.camera.localToGlobal(Vector2(700, 1000));
      final screenDir = north - me;
      // 바늘은 위쪽(0,-1)을 기준으로 angle만큼 회전
      final needle = Vector2(sin(game.compass.angle), -cos(game.compass.angle));
      expect(needle.x, closeTo(screenDir.normalized().x, 1e-3));
      expect(needle.y, closeTo(screenDir.normalized().y, 1e-3));
    },
  );

  // ---------------------------------------------------------------- 자세

  /// 테스트 맵의 낮은 상자 (770~840, 770~840) 바로 아래에서 북쪽을 본다.
  void belowCrate(SoldierGame game, double y) {
    game.player
      ..position = Vector2(805, y)
      ..angle = -pi / 2;
  }

  void run(SoldierGame game, double seconds) {
    for (var i = 0; i < (seconds * 60).round(); i++) {
      game.update(1 / 60);
    }
  }

  gameTester().testGameWidget(
    'walking into a low crate is blocked',
    verify: (game, tester) async {
      belowCrate(game, 900);
      game.player.forward = 1;
      run(game, 1);
      expect(game.player.position.y, greaterThanOrEqualTo(840 + playerRadius));
    },
  );

  gameTester().testGameWidget(
    'jumping while moving clears the crate',
    verify: (game, tester) async {
      belowCrate(game, 880);
      game.player.forward = 1;
      expect(game.player.body.jump(), isTrue);
      run(game, 1);
      expect(game.player.position.y, lessThan(770 - playerRadius));
      expect(game.player.body.airborne, isFalse);
      expect(game.player.body.onCrate, isFalse);
    },
  );

  gameTester().testGameWidget(
    'jump onto the crate -> onCrate, walk off -> not onCrate',
    verify: (game, tester) async {
      belowCrate(game, 875);
      game.player.forward = 0.5; // 0.5s x 264px/s x 0.5 = 66px -> y 809 (상자 안)
      game.player.body.jump();
      run(game, 0.5);
      game.player.forward = 0;
      run(game, 0.1);
      expect(game.player.body.onCrate, isTrue);
      expect(game.player.position.y, inInclusiveRange(770, 840));

      game.player.forward = 1;
      run(game, 1);
      expect(game.player.body.onCrate, isFalse);
      expect(game.player.body.airborne, isFalse);
      expect(game.player.position.y, lessThan(770 - playerRadius));
    },
  );

  gameTester().testGameWidget(
    'running 1s = 220 x 1.5',
    verify: (game, tester) async {
      place(game, 0);
      game.player
        ..forward = 1
        ..wantsRun = true;
      game.update(1);
      expect(game.player.body.running, isTrue);
      expect(game.player.position.x, closeTo(700 + walkSpeed * 1.5, 1));
    },
  );

  gameTester().testGameWidget(
    'crouching 1s = 220 x 0.45',
    verify: (game, tester) async {
      place(game, 0);
      game.player.body.toggleCrouch();
      game.player.forward = 1;
      game.update(1);
      expect(game.player.position.x, closeTo(700 + walkSpeed * 0.45, 1));
    },
  );

  for (final sens in [5.0, 10.0]) {
    gameTester(sensitivity: sens).testGameWidget(
      'arrow key turn 3.0 x (sensitivity/5) rad/s, sensitivity $sens',
      verify: (game, tester) async {
        place(game, 0);
        game.onKeyEvent(
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.arrowRight,
            logicalKey: LogicalKeyboardKey.arrowRight,
            timeStamp: Duration.zero,
          ),
          {LogicalKeyboardKey.arrowRight},
        );
        // 0.5초만: Flame이 각도를 −π~π로 감싸므로 π 안에서 비교.
        game.update(0.5);
        expect(game.player.angle, closeTo(3.0 * sens / 5 * 0.5, 1e-6));
      },
    );
  }

  gameTester().testGameWidget(
    'touch: running joystick + tap DUCK -> crouch and keep moving',
    verify: (game, tester) async {
      place(game, -pi / 2);
      final size = game.size;
      // 손가락 1: 왼쪽에서 조이스틱을 위로 100px (달리기 원 80px 밖)
      final stick = await tester.startGesture(Offset(150, size.y - 150));
      for (var i = 0; i < 10; i++) {
        await stick.moveBy(const Offset(0, -10));
      }
      game.update(1 / 60);
      expect(game.player.body.running, isTrue);

      // 손가락 2: DUCK 버튼 (오른쪽 42, 아래 148, 지름 56)
      final duckCenter = Offset(size.x - 42 - 28, size.y - 148 - 28);
      await tester.tapAt(duckCenter);
      expect(game.player.body.crouching, isTrue);
      expect(game.player.body.running, isFalse);

      // 손가락 1은 그대로 → 앉은 채 계속 전진
      final y0 = game.player.position.y;
      await stick.moveBy(const Offset(0, -2));
      for (var i = 0; i < 60; i++) {
        game.update(1 / 60);
      }
      expect(game.player.body.crouching, isTrue);
      expect(
        y0 - game.player.position.y,
        closeTo(walkSpeed * 0.45, 2),
        reason: 'moves north at crouch speed',
      );

      // 손가락 1을 떼면 멈춤, 다시 잡으면 다시 움직임
      await stick.up();
      game.update(1 / 60);
      final y1 = game.player.position.y;
      game.update(1 / 60);
      expect(game.player.position.y, y1);
      final again = await tester.startGesture(Offset(150, size.y - 150));
      for (var i = 0; i < 5; i++) {
        await again.moveBy(const Offset(0, -10));
      }
      game.update(1 / 60);
      expect(game.player.position.y, lessThan(y1));
      await again.up();
      await tester.pump(const Duration(milliseconds: 100)); // 탭 타이머 정리
    },
  );

  gameTester().testGameWidget(
    'keyboard: Shift+W running, C -> crouch and keep going',
    verify: (game, tester) async {
      place(game, -pi / 2);
      void key(LogicalKeyboardKey k, Set<LogicalKeyboardKey> pressed) =>
          game.onKeyEvent(
            KeyDownEvent(
              physicalKey: PhysicalKeyboardKey.keyA, // 판정엔 logicalKey만 씀
              logicalKey: k,
              timeStamp: Duration.zero,
            ),
            pressed,
          );
      key(LogicalKeyboardKey.keyW, {LogicalKeyboardKey.keyW});
      key(LogicalKeyboardKey.shiftLeft, {
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.shiftLeft,
      });
      game.update(1 / 60);
      expect(game.player.body.running, isTrue);

      key(LogicalKeyboardKey.keyC, {
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.keyC,
      });
      final y0 = game.player.position.y;
      for (var i = 0; i < 60; i++) {
        game.update(1 / 60);
      }
      expect(game.player.body.crouching, isTrue);
      expect(game.player.body.running, isFalse);
      expect(y0 - game.player.position.y, closeTo(walkSpeed * 0.45, 2));
    },
  );
}
