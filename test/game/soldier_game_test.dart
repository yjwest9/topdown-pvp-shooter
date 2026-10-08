import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/game/components/bullet.dart';
import 'package:topsoldier/game/soldier_game.dart';
import 'package:topsoldier/rules/balance.dart';

GameTester<SoldierGame> gameTester({double sensitivity = 5}) => GameTester(
  () => SoldierGame(sensitivity: sensitivity, random: Random(7)),
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
      game.dummies.clear(); // 정면 표적에 자동 사격하면 걷기로 바뀌므로
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
    'joystick held + Space/C keys: jump and crouch keep the joystick moving',
    verify: (game, tester) async {
      place(game, -pi / 2);
      game.dummies.clear();
      void key(LogicalKeyboardKey k) => game.onKeyEvent(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyA, // 판정엔 logicalKey만 씀
          logicalKey: k,
          timeStamp: Duration.zero,
        ),
        {k},
      );
      final stick = await tester.startGesture(Offset(150, game.size.y - 150));
      for (var i = 0; i < 6; i++) {
        await stick.moveBy(const Offset(0, -10));
      }
      game.update(1 / 60);
      final forward = game.player.forward;
      expect(forward, greaterThan(0));

      key(LogicalKeyboardKey.space);
      expect(game.player.forward, forward, reason: 'jump keeps joystick');
      expect(game.player.body.airborne, isTrue);
      key(LogicalKeyboardKey.keyC);
      expect(game.player.forward, forward, reason: 'C keeps joystick');

      final y0 = game.player.position.y;
      game.update(1 / 60);
      expect(game.player.position.y, lessThan(y0), reason: 'still moving');

      await stick.up();
      await tester.pump(const Duration(milliseconds: 100));
    },
  );

  gameTester().testGameWidget(
    'keyboard: Shift+W running, C -> crouch and keep going',
    verify: (game, tester) async {
      place(game, -pi / 2);
      game.dummies.clear();
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

  // ---------------------------------------------------------------- 사격

  void key(SoldierGame game, LogicalKeyboardKey k) => game.onKeyEvent(
    KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyA, // 판정엔 logicalKey만 씀
      logicalKey: k,
      timeStamp: Duration.zero,
    ),
    {k},
  );

  gameTester().testGameWidget(
    'auto fire at dummy 1 (open ground) lowers its hp',
    verify: (game, tester) async {
      place(game, -pi / 2); // 스폰에서 북쪽, 표적 ①은 300px 앞
      final dummy = game.dummies[0];
      run(game, 1);
      expect(dummy.hp, lessThan(100));
      expect(game.player.weapon.ammo, lessThan(30));
    },
  );

  gameTester().testGameWidget(
    'dummy behind a high wall is not hit',
    verify: (game, tester) async {
      // 높은 벽 x 910~940 사이에 두고 동쪽으로 쏜다
      game.player
        ..position = Vector2(850, 700)
        ..angle = 0;
      final dummy = game.dummies[0]..position = Vector2(1000, 700);
      game.fireButtonHeld = true;
      run(game, 2);
      expect(game.player.weapon.ammo, lessThan(30));
      expect(dummy.hp, 100);
    },
  );

  gameTester().testGameWidget(
    'dummy 2 crouched behind a crate: not hit from the front, hit from on top',
    verify: (game, tester) async {
      final dummy = game.dummies[1];
      expect(dummy.crouching, isTrue);
      belowCrate(game, 900);
      game.fireButtonHeld = true;
      run(game, 2);
      expect(game.player.weapon.ammo, lessThan(30));
      expect(dummy.hp, 100);

      game.fireButtonHeld = false;
      run(game, 2); // 재장전 끝까지
      belowCrate(game, 875);
      game.player.forward = 0.5;
      game.player.body.jump();
      run(game, 0.5);
      game.player.forward = 0;
      run(game, 0.1);
      expect(game.player.body.onCrate, isTrue);

      game.fireButtonHeld = true;
      run(game, 1);
      expect(dummy.hp, lessThan(100));
    },
  );

  gameTester().testGameWidget(
    'running: target in the aim -> walk and fire, then run again',
    verify: (game, tester) async {
      place(game, pi / 2); // 남쪽, 표적 없음
      game.player
        ..forward = 1
        ..wantsRun = true;
      run(game, 0.25);
      expect(game.player.body.running, isTrue);
      final ammo = game.player.weapon.ammo;

      game.player
        ..position = Vector2(700, 1000)
        ..angle = -pi / 2; // 탁 트인 곳 표적이 정면
      run(game, 0.25);
      expect(game.player.body.running, isFalse);
      expect(game.player.weapon.ammo, lessThan(ammo));

      game.player.angle = pi / 2; // 다시 표적 없는 쪽
      run(game, 0.25);
      expect(game.player.body.running, isTrue);
    },
  );

  gameTester().testGameWidget(
    'running: holding fire while running walks and fires',
    verify: (game, tester) async {
      place(game, pi / 2);
      game.player
        ..forward = 1
        ..wantsRun = true;
      game.fireButtonHeld = true;
      run(game, 0.25);
      expect(game.player.body.running, isFalse);
      expect(game.player.weapon.ammo, lessThan(30));
    },
  );

  gameTester().testGameWidget(
    'runs only when pushing forward (+-45 degrees)',
    verify: (game, tester) async {
      place(game, pi / 2);
      game.player
        ..wantsRun = true
        ..strafe = 1;
      game.update(1 / 60);
      expect(game.player.body.running, isFalse);
      game.player
        ..strafe = 0
        ..forward = -1;
      game.update(1 / 60);
      expect(game.player.body.running, isFalse);
      game.player.forward = 1;
      game.update(1 / 60);
      expect(game.player.body.running, isTrue);
    },
  );

  gameTester().testGameWidget(
    'crouched right behind a crate: cannot shoot over it',
    verify: (game, tester) async {
      // 낮은 상자 (420~490, 560~630) 남쪽 30px에 앉아 북쪽을 본다
      game.player
        ..position = Vector2(455, 660)
        ..angle = -pi / 2;
      game.player.body.toggleCrouch();
      final dummy = game.dummies[0]..position = Vector2(455, 450);
      final ammo = game.player.weapon.ammo; // 스폰에서 이미 쐈을 수 있음
      run(game, 0.5);
      expect(
        game.player.weapon.ammo,
        ammo,
        reason: 'no auto fire while hidden',
      );

      game.fireButtonHeld = true;
      run(game, 1);
      game.fireButtonHeld = false;
      expect(game.player.weapon.ammo, lessThan(ammo));
      expect(dummy.hp, 100, reason: 'bullets stop at the crate');

      game.player.body.toggleCrouch(); // 일어서면 자동 사격으로 맞힌다
      run(game, 1);
      expect(dummy.hp, lessThan(100));
    },
  );

  gameTester().testGameWidget(
    'emptying the magazine reloads it after the reload time',
    verify: (game, tester) async {
      place(game, pi / 2); // 남쪽 벽 쪽, 표적 없음
      game.fireButtonHeld = true;
      for (var i = 0; i < 600 && game.player.weapon.ammo > 0; i++) {
        game.update(1 / 60);
      }
      expect(game.player.weapon.ammo, 0);
      game.fireButtonHeld = false;
      run(game, rifleStandard.reloadTime - 0.1);
      expect(game.player.weapon.ammo, 0);
      run(game, 0.2);
      expect(game.player.weapon.ammo, 30);
    },
  );

  gameTester().testGameWidget(
    'pump shotgun: one shot spawns 8 pellets',
    verify: (game, tester) async {
      key(game, LogicalKeyboardKey.digit8);
      expect(game.player.weapon.weapon, shotgunPump);
      game.player
        ..position =
            Vector2(700, 850) // 표적 ①에서 150px
        ..angle = -pi / 2;
      game.update(1 / 60); // 자동 사격 1발
      game.update(0); // 총알 붙이기
      expect(
        game.world.children.whereType<Bullet>().where(
          (b) => b.weapon == shotgunPump,
        ),
        hasLength(8),
      );
      expect(game.player.weapon.ammo, 5);
      run(game, 0.5);
      expect(game.dummies[0].hp, lessThan(100));
    },
  );

  gameTester().testGameWidget(
    'switching weapons keeps the ammo of each weapon',
    verify: (game, tester) async {
      place(game, pi / 2);
      key(game, LogicalKeyboardKey.digit3); // 정밀형 15발
      game.fireButtonHeld = true;
      game.update(1 / 60);
      game.fireButtonHeld = false;
      expect(game.player.weapon.ammo, 14);
      key(game, LogicalKeyboardKey.digit2);
      key(game, LogicalKeyboardKey.digit3);
      expect(game.player.weapon.ammo, 14);
      game.update(1 / 60);
      expect(game.player.weapon.ammo, 14, reason: 'not refilled');
    },
  );

  gameTester().testGameWidget(
    'tap weapon slots (top right): secondary, then primary',
    verify: (game, tester) async {
      place(game, pi / 2);
      final size = game.size;
      // 보조 = 맨 오른쪽, 주무기 = 그 왼쪽 (슬롯 130x56, 여백 16, 간격 8)
      await tester.tapAt(Offset(size.x - 16 - 65, 16 + 28));
      expect(game.player.weapon.weapon, pistol);
      await tester.tapAt(Offset(size.x - 16 - 130 - 8 - 65, 16 + 28));
      expect(game.player.weapon.weapon, rifleStandard);
      await tester.pump(const Duration(milliseconds: 100)); // 탭 타이머 정리
    },
  );

  gameTester().testGameWidget(
    'keys: Q swaps to the pistol, R reloads',
    verify: (game, tester) async {
      place(game, pi / 2);
      key(game, LogicalKeyboardKey.keyQ);
      expect(game.player.weapon.weapon, pistol);
      game.fireButtonHeld = true;
      game.update(1 / 60);
      game.fireButtonHeld = false;
      expect(game.player.weapon.ammo, 11);
      key(game, LogicalKeyboardKey.keyR);
      expect(game.player.weapon.reloading, isTrue);
      key(game, LogicalKeyboardKey.keyQ); // 교체하면 재장전 취소
      expect(game.player.secondary.reloading, isFalse);
      expect(game.player.weapon.weapon, rifleStandard);
    },
  );

  gameTester().testGameWidget(
    'heavy MG moves at x0.75',
    verify: (game, tester) async {
      key(game, LogicalKeyboardKey.digit4);
      place(game, 0);
      game.player.forward = 1;
      game.update(1);
      expect(game.player.position.x, closeTo(700 + walkSpeed * 0.75, 1));
    },
  );

  gameTester().testGameWidget(
    'touch: hold FIRE (manual weapon) shoots, dragging it turns',
    verify: (game, tester) async {
      key(game, LogicalKeyboardKey.digit5); // 볼트액션, 수동
      place(game, pi / 2);
      final size = game.size;
      final fire = await tester.startGesture(Offset(size.x - 70, size.y - 82));
      game.update(1 / 60);
      expect(game.player.weapon.ammo, 4);
      // 끌어도 사격은 이어진다
      await fire.moveBy(const Offset(50, 0));
      await fire.moveBy(const Offset(50, 0));
      expect(game.fireButtonHeld, isTrue);
      expect(game.player.angle, closeTo(pi / 2 + 0.75, 1e-3));
      run(game, sniperBolt.fireInterval + 0.1);
      expect(game.player.weapon.ammo, 3);
      await fire.up();
      expect(game.fireButtonHeld, isFalse);
      await tester.pump(const Duration(milliseconds: 100)); // 탭 타이머 정리
    },
  );
}
