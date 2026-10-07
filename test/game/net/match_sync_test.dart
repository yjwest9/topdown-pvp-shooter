import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/models/match_stats.dart';
import 'package:topsoldier/data/repositories/room_repository.dart';
import 'package:topsoldier/game/components/bullet.dart';
import 'package:topsoldier/game/components/test_map.dart';
import 'package:topsoldier/game/net/match_sync.dart';
import 'package:topsoldier/game/soldier_game.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/combat.dart';
import 'package:topsoldier/rules/match.dart';

import '../../fakes.dart';

const code = '1234';

/// 나는 'a'(방장). [db.serverTime]이 곧 내 시계(오프셋 0).
GameTester<SoldierGame> onlineTester(FakeRtdbService db) => GameTester(
  () => SoldierGame(
    random: Random(7),
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

Map<String, Object?> state(double x, double y, {String stance = 'standing'}) =>
    {
      'x': x,
      'y': y,
      'a': 1.0,
      'stance': stance,
      'up': 0.0,
      'weapon': 'pistol',
      't': {'.sv': 'timestamp'},
    };

void main() {
  final db = FakeRtdbService();
  setUp(db.reset);

  onlineTester(db).testGameWidget(
    'sends my state 15 times per second',
    verify: (game, tester) async {
      for (var i = 0; i < 120; i++) {
        game.update(1 / 60);
        await tester.pump(); // 기록 완료(마이크로태스크)를 처리
      }
      expect(db.writes['rooms/$code/states/a'], closeTo(2 * stateSendHz, 1));
      final sent = await db.get('rooms/$code/states/a') as Map;
      expect(sent['x'], game.player.position.x);
      expect(sent['stance'], isA<String>());
    },
  );

  onlineTester(db).testGameWidget(
    'does not pile up state writes while the server does not answer',
    verify: (game, tester) async {
      db.hold = Completer<void>();
      addTearDown(() => db.hold = null);
      for (var i = 0; i < 120; i++) {
        game.update(1 / 60);
        await tester.pump();
      }
      expect(db.writes['rooms/$code/states/a'], 1);

      db.hold!.complete();
      await tester.pump();
      game.update(1 / 15);
      await tester.pump();
      expect(db.writes['rooms/$code/states/a'], greaterThan(1)); // 다시 보냄
    },
  );

  onlineTester(db).testGameWidget(
    'leave marks me disconnected, removes my state and stops sending',
    verify: (game, tester) async {
      game.update(1 / 15);
      await tester.pump();
      expect(await db.get('rooms/$code/states/a'), isNotNull);

      await game.match!.leave();
      for (var i = 0; i < 30; i++) {
        game.update(1 / 60);
        await tester.pump();
      }
      expect(await db.get('rooms/$code/states/a'), isNull);
      expect(await db.get('rooms/$code/players/a/connected'), false);
    },
  );

  onlineTester(db).testGameWidget(
    'host spawns south, no training dummies online',
    verify: (game, tester) async {
      expect(game.player.position.y, TestMap.spawn.y);
      expect(game.dummies, isEmpty);
    },
  );

  onlineTester(db).testGameWidget(
    'received opponent state shows on remote player',
    verify: (game, tester) async {
      await db.set(
        'rooms/$code/states/b',
        state(300, 400, stance: 'crouching'),
      );
      db.serverTime += 500; // 지연(100ms)보다 충분히 뒤
      await tester.pump();
      game.update(1 / 60);

      final r = game.match!.remotes['b']!;
      expect(r.position.x, 300);
      expect(r.position.y, 400);
      expect(r.angle, 1.0);
      expect(r.coverBody.crouching, true);
      expect(game.match!.remotes.containsKey('a'), false); // 나는 안 그림
    },
  );

  onlineTester(db).testGameWidget(
    'remote is drawn 100ms late, interpolated between snapshots',
    verify: (game, tester) async {
      await db.set('rooms/$code/states/b', state(0, 0));
      db.serverTime = 1100;
      await db.set('rooms/$code/states/b', state(100, 0));
      db.serverTime = 1150; // 재생 시각 1050 = 두 스냅샷 가운데
      await tester.pump();
      game.update(1 / 60);

      expect(game.match!.remotes['b']!.position.x, closeTo(50, 1e-9));
    },
  );

  onlineTester(db).testGameWidget(
    "opponent's shot becomes a cosmetic bullet on my screen",
    verify: (game, tester) async {
      await db.push('rooms/$code/shots', {
        'by': 'b',
        'x': 700.0,
        'y': 400.0,
        'a': pi / 2,
        'weapon': 'pistol',
        't': {'.sv': 'timestamp'},
      });
      db.serverTime += 200;
      await tester.pump();
      game.update(1 / 60);
      await tester.pump();

      final bullets = game.world.children.whereType<Bullet>();
      expect(bullets.where((b) => !b.hitsTargets), hasLength(1));
    },
  );

  /// onMatchEnd 기록용.
  ({MatchStats stats, bool opponentLeft})? ended;
  void listenEnd(SoldierGame game) {
    ended = null;
    game.match!.onMatchEnd = (stats, {required opponentLeft}) =>
        ended = (stats: stats, opponentLeft: opponentLeft);
  }

  Future<void> bothPlaying({required int endsIn}) async {
    await db.update('rooms/$code/meta', {
      'hostUid': 'a',
      'status': 'playing',
      'endsAt': db.serverTime + endsIn,
    });
    await db.set('rooms/$code/players/a', {
      'name': 'A',
      'connected': true,
      'team': 'A',
    });
    await db.set('rooms/$code/players/b', {
      'name': 'B',
      'connected': true,
      'team': 'B',
    });
  }

  onlineTester(db).testGameWidget(
    'opponent leaving mid-match: I win, once',
    verify: (game, tester) async {
      listenEnd(game);
      await db.set('rooms/$code/players/b', {'name': 'B', 'connected': true});
      await tester.pump();
      expect(ended, isNull);

      await db.set('rooms/$code/players/b/connected', false);
      await db.set('rooms/$code/players/b/connected', false);
      await tester.pump();
      expect(ended!.opponentLeft, true);
      expect(ended!.stats.result, MatchResult.win);
    },
  );

  // ------------------------------------------------------------- 전투

  Future<void> setHp(String id, double value, {int protectedUntil = 0}) =>
      db.set('rooms/$code/hp/$id', {
        'value': value,
        'protectedUntil': protectedUntil,
      });

  const hit13 = HitResult(miss: false, crit: false, damage: 13);

  onlineTester(db).testGameWidget(
    'on start I write my full hp with spawn protection',
    verify: (game, tester) async {
      await tester.pump();
      final hp = await db.get('rooms/$code/hp/a') as Map;
      expect(hp['value'], basicSoldier.hp);
      expect(hp['protectedUntil'], db.serverTime + spawnProtectionMs);
    },
  );

  onlineTester(db).testGameWidget(
    'my hit lowers the opponent hp by transaction',
    verify: (game, tester) async {
      await setHp('b', 100);
      game.match!.hit('b', hit13, rifleStandard);
      await tester.pump();
      expect((await db.get('rooms/$code/hp/b') as Map)['value'], 87);
      expect(await db.get('rooms/$code/kills'), isNull);
    },
  );

  onlineTester(db).testGameWidget(
    'hit that takes hp to 0 records a kill and +1 to my team',
    verify: (game, tester) async {
      await setHp('b', 10);
      game.match!.hit('b', hit13, rifleStandard);
      await tester.pump();

      expect((await db.get('rooms/$code/hp/b') as Map)['value'], 0);
      final kills = (await db.get('rooms/$code/kills') as Map).values;
      expect(kills, hasLength(1));
      expect((kills.single as Map)['killer'], 'a');
      expect((kills.single as Map)['victim'], 'b');
      expect(await db.get('rooms/$code/score/A'), 1);

      // 이미 0이면 더 깎거나 킬을 또 세지 않는다.
      game.match!.hit('b', hit13, rifleStandard);
      await tester.pump();
      expect(await db.get('rooms/$code/score/A'), 1);
    },
  );

  onlineTester(db).testGameWidget(
    'spawn-protected opponent takes no damage',
    verify: (game, tester) async {
      await setHp('b', 100, protectedUntil: db.serverTime + 1000);
      game.match!.hit('b', hit13, rifleStandard);
      await tester.pump();
      expect((await db.get('rooms/$code/hp/b') as Map)['value'], 100);
    },
  );

  onlineTester(db).testGameWidget(
    'my auto-fire hits the opponent in front (my screen decides)',
    verify: (game, tester) async {
      await setHp('b', 100);
      // 나는 (700,1000)에서 북쪽을 본다. 상대는 정면 250px.
      await db.set('rooms/$code/states/b', state(700, 750));
      db.serverTime += 500;
      for (var i = 0; i < 90; i++) {
        game.update(1 / 60);
        await tester.pump();
      }
      expect((await db.get('rooms/$code/hp/b') as Map)['value'], lessThan(100));
    },
  );

  onlineTester(db).testGameWidget(
    'when I die: dead for 5s, then back at my spawn with full hp + protection',
    verify: (game, tester) async {
      await tester.pump();
      game.player.position = Vector2(300, 300);
      await setHp('a', 0);
      await tester.pump();
      expect(game.match!.isDead, true);

      for (var i = 0; i < (respawnDelay * 60).round() + 2; i++) {
        game.update(1 / 60);
        await tester.pump();
      }
      final hp = await db.get('rooms/$code/hp/a') as Map;
      expect(hp['value'], basicSoldier.hp);
      expect(hp['protectedUntil'], db.serverTime + spawnProtectionMs);
      expect(game.match!.isDead, false);
      expect(game.player.position.y, TestMap.spawn.y);
    },
  );

  onlineTester(db).testGameWidget(
    'host ends the match at $killsToWin kills and both see the result',
    verify: (game, tester) async {
      listenEnd(game);
      await bothPlaying(endsIn: 60000);
      await db.set('rooms/$code/score/A', killsToWin);
      await tester.pump();
      game.update(1 / 60);
      await tester.pump();

      expect(await db.get('rooms/$code/meta/status'), 'ended');
      expect(await db.get('rooms/$code/meta/winner'), 'A');
      expect(ended!.stats.result, MatchResult.win);
      expect(ended!.opponentLeft, false);
    },
  );

  onlineTester(db).testGameWidget(
    'time up with equal score is a draw',
    verify: (game, tester) async {
      listenEnd(game);
      await bothPlaying(endsIn: 1000);
      await tester.pump();
      game.update(1 / 60);
      expect(await db.get('rooms/$code/meta/status'), 'playing');

      db.serverTime += 1000;
      game.update(1 / 60);
      await tester.pump();
      expect(await db.get('rooms/$code/meta/winner'), 'draw');
      expect(ended!.stats.result, MatchResult.draw);
    },
  );
}
