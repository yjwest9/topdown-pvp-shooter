import 'dart:math';

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
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/character.dart';

import '../fakes.dart';

/// 캐릭터가 게임에 반영되는지(decisions 5장·8장).
GameTester<SoldierGame> tester(
  CharacterStats character, {
  FakeRtdbService? db,
}) => GameTester(
  () => SoldierGame(
    random: Random(7),
    character: character,
    match: db == null
        ? null
        : MatchSync(
            rooms: RoomRepository(db),
            code: '1234',
            uid: 'a',
            isHost: true,
            clock: () => db.serverTime,
          ),
  ),
  createGameWidget: (game) =>
      RiverpodAwareGameWidget(key: GlobalKey(), game: game),
  pumpWidget: (widget, t) => t.pumpWidget(ProviderScope(child: widget)),
);

void main() {
  final db = FakeRtdbService();
  setUp(db.reset);

  /// 열린 공간에서 1초 앞으로 걸은 거리.
  double walkOneSecond(SoldierGame game) {
    game.player
      ..position = Vector2(700, 1000)
      ..angle = 0
      ..forward = 1;
    game.update(1);
    return game.player.position.x - 700;
  }

  double? basicDistance;
  tester(basicSoldier).testGameWidget(
    'basic soldier walk distance',
    verify: (game, _) async => basicDistance = walkOneSecond(game),
  );
  tester(upgradedCharacter(scout, 0)).testGameWidget(
    'scout walks 5% farther than the basic soldier in the same time',
    verify: (game, _) async {
      expect(walkOneSecond(game), closeTo(basicDistance! * 1.05, 1e-6));
    },
  );

  tester(upgradedCharacter(basicSoldier, 5), db: db).testGameWidget(
    'basic soldier +5: full hp is 110 at start and after respawn',
    verify: (game, t) async {
      await t.pump();
      expect((await db.get('rooms/1234/hp/a') as Map)['value'], 110);

      await db.set('rooms/1234/hp/a', {'value': 0, 'protectedUntil': 0});
      await t.pump();
      for (var i = 0; i < (respawnDelay * 60).round() + 2; i++) {
        game.update(1 / 60);
        await t.pump();
      }
      expect((await db.get('rooms/1234/hp/a') as Map)['value'], 110);
    },
  );

  tester(basicSoldier, db: db).testGameWidget(
    "opponent's character evasion (room players) goes into my miss chance",
    verify: (game, t) async {
      await db.set('rooms/1234/players/b', {
        'name': 'B',
        'connected': true,
        'team': 'B',
        'character': 'scout',
        'characterLevel': 5,
      });
      await db.set('rooms/1234/hp/b', {'value': 90, 'protectedUntil': 0});
      await db.set('rooms/1234/states/b', {
        'x': 1085.0,
        'y': 1365.0,
        'a': 1.0,
        'stance': 'standing',
        'up': 0.0,
        'weapon': 'pistol',
        't': {'.sv': 'timestamp'},
      });
      db.serverTime += 500;
      await t.pump();
      game.update(1 / 60);

      final target = game.hitTargets.single;
      final bullet = Bullet(
        position: Vector2.zero(),
        angle: 0,
        weapon: rifleStandard,
        shooter: game.player.coverBody,
        character: game.character,
      );
      // 5% + 정찰병 +5 회피 13% − 내 명중 0
      expect(bullet.missChanceAgainst(target), closeTo(0.18, 1e-9));
      // 상대 체력 바도 상대 최대 체력(정찰병 90) 기준.
      expect(game.match!.characterOf('b').hp, 90);
    },
  );

  tester(upgradedCharacter(marksman, 5), db: db).testGameWidget(
    'my accuracy lowers the miss chance against a basic soldier',
    verify: (game, t) async {
      final bullet = Bullet(
        position: Vector2.zero(),
        angle: 0,
        weapon: rifleStandard,
        shooter: game.player.coverBody,
        character: game.character,
      );
      final dummy = (
        key: 'x',
        body: game.player.coverBody,
        stance: game.player.stance,
        protected: false,
        evasion: 0.0,
        onHit: (_, _) {},
      );
      // 5% + 0 − 13% → 0
      expect(bullet.missChanceAgainst(dummy), 0);
    },
  );
}
