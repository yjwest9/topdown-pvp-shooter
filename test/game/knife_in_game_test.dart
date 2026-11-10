import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/repositories/room_repository.dart';
import 'package:topsoldier/game/components/bullet.dart';
import 'package:topsoldier/game/components/swing_arc.dart';
import 'package:topsoldier/game/net/match_sync.dart';
import 'package:topsoldier/game/soldier_game.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/combat.dart';
import 'package:topsoldier/rules/match.dart';

import '../fakes.dart';

const code = '1234';

/// 훈련소, 보조 칸에 칼. 칼을 든 상태로 시작.
GameTester<SoldierGame> trainingTester() => GameTester(
  // 주무기 자동 사격이 시작부터 표적을 쏘지 않게 수동.
  () => SoldierGame(
    random: Random(7),
    secondary: knife,
    primaryFireMode: FireMode.manual,
  ),
  createGameWidget: (game) =>
      RiverpodAwareGameWidget(key: GlobalKey(), game: game),
  pumpWidget: (widget, tester) =>
      tester.pumpWidget(ProviderScope(child: widget)),
);

GameTester<SoldierGame> onlineKnife(FakeRtdbService db) => GameTester(
  () => SoldierGame(
    random: Random(7),
    secondary: knife,
    primaryFireMode: FireMode.manual,
    match: MatchSync(
      rooms: RoomRepository(db),
      code: code,
      uid: 'a',
      isHost: true,
      clock: () => db.serverTime,
    ),
  ),
  createGameWidget: (game) =>
      RiverpodAwareGameWidget(key: GlobalKey(), game: game),
  pumpWidget: (widget, tester) =>
      tester.pumpWidget(ProviderScope(child: widget)),
);

void run(SoldierGame game, double seconds) {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    game.update(1 / 60);
  }
}

void main() {
  trainingTester().testGameWidget(
    'knife: swings kill a training dummy, no bullets, no ammo used',
    verify: (game, tester) async {
      game.player.selectSlot(primary: false);
      final dummy = game.dummies[0]; // (700, 700), 열린 곳
      game.player
        ..position =
            Vector2(700, 780) // 80px 남쪽
        ..angle = -pi / 2;
      game.fireButtonHeld = true;
      var bullets = 0;
      for (var i = 0; i < 60 * 4 && !dummy.dead; i++) {
        game.update(1 / 60);
        bullets += game.world.children.whereType<Bullet>().length;
      }
      expect(dummy.dead, isTrue); // 40 + 40 + 20(크리면 더 빨리)
      expect(bullets, 0);
      expect(game.swings, inInclusiveRange(2, 6));
      expect(game.player.weapon.ammo, 0);
      expect(game.player.weapon.reloading, isFalse);
    },
  );

  trainingTester().testGameWidget(
    'knife: swing interval is 0.4s and a swing shows an arc',
    verify: (game, tester) async {
      game.player
        ..selectSlot(primary: false)
        ..position = Vector2(700, 1000)
        ..angle = 0;
      game.fireButtonHeld = true;
      game.update(1 / 60);
      expect(game.swings, 1);
      game.update(0.001); // 추가한 호가 붙는다
      expect(game.world.children.whereType<SwingArc>(), hasLength(1));
      run(game, 0.3);
      expect(game.swings, 1);
      run(game, 0.12);
      expect(game.swings, 2);
    },
  );

  trainingTester().testGameWidget(
    'knife: a dummy out of reach (200px) is not hurt',
    verify: (game, tester) async {
      game.player.selectSlot(primary: false);
      final dummy = game.dummies[0];
      game.player
        ..position =
            Vector2(700, 900) // 200px
        ..angle = -pi / 2;
      game.fireButtonHeld = true;
      run(game, 1);
      expect(game.swings, greaterThan(0));
      expect(dummy.hp, 100);
    },
  );

  trainingTester().testGameWidget(
    'knife auto swing follows the weapon range (80, centre distance)',
    verify: (game, tester) async {
      game.player.selectSlot(primary: false);
      // 표적 ①(700, 700) 정면. 사거리 80보다 먼 100px에서는 자동으로 안 휘두른다.
      game.player
        ..position = Vector2(700, 800)
        ..angle = -pi / 2;
      run(game, 1);
      expect(game.swings, 0);

      game.player.position = Vector2(700, 770); // 70px
      run(game, 1);
      expect(game.swings, greaterThan(0));
    },
  );

  final db = FakeRtdbService();
  setUp(db.reset);

  Future<void> pump(SoldierGame game, WidgetTester tester, int frames) async {
    for (var i = 0; i < frames; i++) {
      game.update(1 / 60);
      await tester.pump();
    }
  }

  Map<String, Object?> remote(double x, double y, {int sw = 0}) => {
    'x': x,
    'y': y,
    'a': 1.0,
    'stance': 'standing',
    'up': 0.0,
    'weapon': 'knife',
    'sw': sw,
    't': {'.sv': 'timestamp'},
  };

  onlineKnife(db).testGameWidget(
    'knife online: states.sw counts swings, shots stay empty, opponent is hurt',
    verify: (game, tester) async {
      await db.set('rooms/$code/hp/b', {'value': 100.0, 'protectedUntil': 0});
      game.player
        ..selectSlot(primary: false)
        ..position = Vector2(1085, 1575)
        ..angle = -pi / 2;
      await db.set('rooms/$code/states/b', remote(1085, 1500)); // 75px 앞
      db.serverTime += 500;
      game.fireButtonHeld = true;
      await pump(game, tester, 60);

      expect(game.swings, greaterThan(1));
      final sent = await db.get('rooms/$code/states/a') as Map;
      expect(sent['sw'], greaterThan(0));
      expect(sent['weapon'], 'knife');
      expect(await db.get('rooms/$code/shots'), isNull);
      final hp = (await db.get('rooms/$code/hp/b') as Map)['value'] as num;
      expect(hp, lessThan(100));
      expect(hp, lessThanOrEqualTo(60));
    },
  );

  onlineKnife(db).testGameWidget(
    'knife stats: one swing counts at most one hit, so accuracy stays <= 100%',
    verify: (game, tester) async {
      const h = HitResult(miss: false, crit: false, damage: 40);
      final m = game.match!;
      game.swings = 1;
      m.countSwing();
      m.hit('b', h, knife);
      m.hit('c', h, knife); // 같은 휘두름에서 둘째 대상
      var st = m.statsFor(MatchResult.win);
      expect((st.shots, st.hits), (1, 1));

      game.swings = 2; // 다음 휘두름은 다시 센다
      m.countSwing();
      m.hit('b', h, knife);
      st = m.statsFor(MatchResult.win);
      expect((st.shots, st.hits), (2, 2));

      // 총알은 그대로: 맞힌 만큼 센다.
      m.hit('b', h, rifleStandard);
      m.hit('b', h, rifleStandard);
      expect(m.statsFor(MatchResult.win).hits, 4);
    },
  );

  onlineKnife(db).testGameWidget(
    "opponent's swing (sw goes up) shows an arc on my screen",
    verify: (game, tester) async {
      await db.set('rooms/$code/states/b', remote(300, 400));
      db.serverTime += 200;
      await pump(game, tester, 2);
      expect(game.world.children.whereType<SwingArc>(), isEmpty);

      await db.set('rooms/$code/states/b', remote(300, 400, sw: 1));
      db.serverTime += 300;
      await pump(game, tester, 2);
      final arcs = game.world.children.whereType<SwingArc>();
      expect(arcs, hasLength(1));
      expect(arcs.single.mine, isFalse);
    },
  );
}
