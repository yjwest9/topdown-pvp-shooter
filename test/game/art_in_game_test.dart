import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/repositories/room_repository.dart';
import 'package:topsoldier/game/components/bullet.dart';
import 'package:topsoldier/game/net/match_sync.dart';
import 'package:topsoldier/game/soldier_game.dart';
import 'package:topsoldier/rules/appearance.dart';
import 'package:topsoldier/rules/balance.dart';

import '../fakes.dart';

/// 그림을 불러온 상태에서 게임이 시작하고 그려지는지(decisions 3장·4장·8장).
GameTester<SoldierGame> offline() => GameTester(
  () => SoldierGame(random: Random(7)),
  createGameWidget: (game) =>
      RiverpodAwareGameWidget(key: GlobalKey(), game: game),
  pumpWidget: (widget, tester) =>
      tester.pumpWidget(ProviderScope(child: widget)),
);

GameTester<SoldierGame> online(FakeRtdbService db) => GameTester(
  () => SoldierGame(
    random: Random(7),
    match: MatchSync(
      rooms: RoomRepository(db),
      code: '1234',
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

/// 게임 전체를 그림으로 그려 본다(예외 없이 끝나면 통과).
void renderOnce(SoldierGame game) {
  final recorder = PictureRecorder();
  game.render(Canvas(recorder));
  recorder.endRecording().dispose();
}

void main() {
  final db = FakeRtdbService();
  setUp(db.reset);

  offline().testGameWidget(
    'training: every game image is loaded and the map is baked into one image',
    verify: (game, tester) async {
      for (final f in artFiles) {
        expect(game.images.containsKey(f), true, reason: f);
      }
      // 훈련소 맵 1400×1400 전체가 한 장.
      expect(game.map.bakedImage!.width, 1400);
      expect(game.map.bakedImage!.height, 1400);
      renderOnce(game); // 병사·표적·맵 그리기 중 예외 없음
    },
  );

  online(db).testGameWidget(
    'match: outpost baked into one 2170px image, opponent drawn with his character',
    verify: (game, tester) async {
      expect(game.map.bakedImage!.width, 2170);
      await db.set('rooms/1234/players/b', {
        'name': 'B',
        'connected': true,
        'team': 'B',
        'character': 'assault',
        'characterLevel': 2,
      });
      await db.set('rooms/1234/hp/b', {'value': 95, 'protectedUntil': 0});
      await db.set('rooms/1234/states/b', {
        'x': 1085.0,
        'y': 1365.0,
        'a': 1.0,
        'stance': 'standing',
        'up': 0.0,
        'weapon': 'sniper_bolt',
        't': {'.sv': 'timestamp'},
      });
      db.serverTime += 500;
      await tester.pump();
      game.update(1 / 60);
      expect(game.match!.characterOf('b').id, 'assault');
      expect(game.match!.remotes['b']!.pose, Pose.silencer); // 저격총
      await db.set('rooms/1234/states/b', {
        'x': 1085.0,
        'y': 1365.0,
        'a': 1.0,
        'stance': 'standing',
        'up': 0.0,
        'weapon': 'sniper_bolt',
        'rl': true,
        't': {'.sv': 'timestamp'},
      });
      db.serverTime += 500;
      await tester.pump();
      game.update(1 / 60);
      expect(game.match!.remotes['b']!.pose, Pose.reload); // 상대 재장전
      renderOnce(game); // 돌격병 + 저격총(silencer) 포즈로 상대를 그린다
    },
  );

  offline().testGameWidget(
    'my soldier draws in every pose, crouching and jumping',
    verify: (game, tester) async {
      for (final w in weapons) {
        game.player.selectPrimary(w);
        renderOnce(game);
        game.player.weapon.reload(); // reload 포즈
        renderOnce(game);
      }
      game.player.body.toggleCrouch();
      renderOnce(game);
      game.player.body.toggleCrouch();
      game.player.body.jump();
      renderOnce(game);
      game.update(1 / 60);
      expect(game.player.position, isA<Vector2>());
    },
  );

  test('tracer colour: my bullet vs opponent (cosmetic) and bot bullets', () {
    Bullet b({bool hits = true, List<HitTarget> Function()? targets}) => Bullet(
      position: Vector2.zero(),
      angle: 0,
      weapon: rifleStandard,
      shooter: (
        pos: (x: 0, y: 0),
        crouching: false,
        airborne: false,
        onCrate: false,
      ),
      hitsTargets: hits,
      targets: targets,
    );
    expect(b().mine, true);
    expect(b(hits: false).mine, false); // 상대가 쏜 총알(내 화면 연출)
    expect(b(targets: () => const []).mine, false); // 봇 총알
  });
}
