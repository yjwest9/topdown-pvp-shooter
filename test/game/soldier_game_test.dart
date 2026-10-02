import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flame_test/flame_test.dart';
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
}
