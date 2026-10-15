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

/// 나는 'b'(참가자). 방장 'a'가 사라질 수 있다.
GameTester<SoldierGame> joinerTester(FakeRtdbService db) => GameTester(
  () => SoldierGame(
    random: Random(7),
    match: MatchSync(
      rooms: RoomRepository(db),
      code: code,
      uid: 'b',
      isHost: false,
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
    'my state says whether I am reloading (rl), so the opponent sees it',
    verify: (game, tester) async {
      game.player.weapon.ammo = 5;
      game.player.weapon.reload();
      for (var i = 0; i < 10; i++) {
        game.update(1 / 60);
        await tester.pump();
      }
      expect((await db.get('rooms/$code/states/a') as Map)['rl'], true);
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
      // 상대가 남아 있다(혼자면 마지막 사람이라 방이 통째로 지워진다).
      await db.set('rooms/$code/players/b', {'connected': true});

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
    'host starts at an A spawn of the PvP map, no training dummies',
    verify: (game, tester) async {
      final me = (x: game.player.position.x, y: game.player.position.y);
      expect(game.map.spawnsOf('A'), contains(me));
      expect(game.map.width, 2170);
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

  Future<void> pumpFrames(SoldierGame game, WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      game.update(1 / 60);
      await tester.pump();
    }
  }

  onlineTester(db).testGameWidget(
    'opponent leaving mid-match: I win once, after the grace',
    verify: (game, tester) async {
      listenEnd(game);
      await db.set('rooms/$code/players/b', {'name': 'B', 'connected': true});
      await pumpFrames(game, tester);
      expect(ended, isNull);

      await db.set('rooms/$code/players/b/connected', false);
      await db.set('rooms/$code/players/b/connected', false);
      await pumpFrames(game, tester);
      expect(ended, isNull); // 바로는 안 끝남
      db.serverTime += stuckGraceMs + 500;
      await pumpFrames(game, tester);
      expect(ended!.opponentLeft, true);
      expect(ended!.stats.result, MatchResult.win);
    },
  );

  onlineTester(db).testGameWidget(
    'opponent flag drops for 2 seconds and comes back: not over',
    verify: (game, tester) async {
      listenEnd(game);
      await db.set('rooms/$code/players/b', {'name': 'B', 'connected': true});
      await pumpFrames(game, tester);

      await db.set('rooms/$code/players/b/connected', false);
      db.serverTime += 2000;
      await pumpFrames(game, tester);
      await db.set('rooms/$code/players/b/connected', true);
      db.serverTime += stuckGraceMs * 3;
      await pumpFrames(game, tester);
      expect(ended, isNull);
    },
  );

  onlineTester(db).testGameWidget(
    'opponent entry is removed (room gone) after I saw him: I win after the '
    'grace',
    verify: (game, tester) async {
      listenEnd(game);
      await db.set('rooms/$code/players/b', {'name': 'B', 'connected': true});
      await pumpFrames(game, tester);
      await db.remove('rooms/$code/players/b');
      await pumpFrames(game, tester);
      expect(ended, isNull);
      db.serverTime += stuckGraceMs + 500;
      await pumpFrames(game, tester);
      expect(ended!.stats.result, MatchResult.win);
    },
  );

  // 시연 위험(docs/demo-risks.md 2·3-1): 끊김·방장 실종에서 끝나지 않고 멈추던 것.

  joinerTester(db).testGameWidget(
    'host is already gone when I look (never saw him connected): I win',
    verify: (game, tester) async {
      listenEnd(game);
      await db.update('rooms/$code/meta', {
        'hostUid': 'a',
        'status': 'playing',
        'endsAt': db.serverTime + 100000,
      });
      await db.set('rooms/$code/players/a', {'connected': false, 'team': 'A'});
      await db.set('rooms/$code/players/b', {'connected': true, 'team': 'B'});
      await pumpFrames(game, tester);
      expect(ended, isNull); // 바로는 안 끝남(유예)
      db.serverTime += stuckGraceMs + 500;
      await pumpFrames(game, tester);
      expect(ended!.opponentLeft, true);
      expect(ended!.stats.result, MatchResult.win);
    },
  );

  joinerTester(db).testGameWidget(
    'host alive on paper but nobody writes the end: I end it myself '
    'a few seconds after time is up',
    verify: (game, tester) async {
      listenEnd(game);
      await bothPlaying(endsIn: 1000);
      await pumpFrames(game, tester);
      expect(ended, isNull);

      db.serverTime += 1000 + 3000; // 끝난 지 3초: 아직 기다림
      await pumpFrames(game, tester);
      expect(ended, isNull);

      db.serverTime += 3000; // 6초 넘음
      await pumpFrames(game, tester);
      expect(ended!.opponentLeft, false);
      expect(ended!.stats.result, MatchResult.draw); // 0:0
    },
  );

  joinerTester(db).testGameWidget(
    'my own connection was flagged lost (I came back after a drop): I lose',
    verify: (game, tester) async {
      listenEnd(game);
      await bothPlaying(endsIn: 100000);
      await pumpFrames(game, tester);
      expect(ended, isNull);

      await db.set('rooms/$code/players/b/connected', false); // onDisconnect
      await pumpFrames(game, tester);
      expect(ended, isNull); // 바로는 안 끝남(유예)
      db.serverTime += stuckGraceMs + 500;
      await pumpFrames(game, tester);
      expect(ended!.stats.result, MatchResult.lose);
    },
  );

  // 오판 방지: 잘못 끝내지 않는다.

  joinerTester(db).testGameWidget(
    'match just started and the host connected flag is not written yet: not over',
    verify: (game, tester) async {
      listenEnd(game);
      await db.update('rooms/$code/meta', {
        'hostUid': 'a',
        'status': 'playing',
        'endsAt': db.serverTime + 100000,
      });
      await db.set('rooms/$code/players/a', {'name': 'A', 'team': 'A'});
      await db.set('rooms/$code/players/b', {'connected': true, 'team': 'B'});
      await pumpFrames(game, tester);
      db.serverTime += 1000;
      await pumpFrames(game, tester);
      expect(ended, isNull);

      // 곧 방장의 connected가 써진다.
      await db.set('rooms/$code/players/a/connected', true);
      db.serverTime += stuckGraceMs + 2000;
      await pumpFrames(game, tester);
      expect(ended, isNull);
    },
  );

  joinerTester(db).testGameWidget(
    'my connected flag drops and comes back within the grace (home button): '
    'not over',
    verify: (game, tester) async {
      listenEnd(game);
      await bothPlaying(endsIn: 100000);
      await pumpFrames(game, tester);

      await db.set('rooms/$code/players/b/connected', false);
      db.serverTime += stuckGraceMs - 1000;
      await pumpFrames(game, tester);
      await db.set('rooms/$code/players/b/connected', true);
      db.serverTime += stuckGraceMs * 3;
      await pumpFrames(game, tester);
      expect(ended, isNull);
    },
  );

  onlineTester(db).testGameWidget(
    'host: my own connected flag is not read as a drop before it is first set',
    verify: (game, tester) async {
      listenEnd(game);
      await db.set('rooms/$code/players/a', {'name': 'A', 'team': 'A'});
      await pumpFrames(game, tester);
      expect(ended, isNull);
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
      expect(game.killBanner.showing, isFalse); // 안 죽었으면 처치 표시 없음
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
      // 처치 표시
      expect(game.killBanner.showing, isTrue);
      expect(game.killBanner.victim, game.match!.nameOf('b'));

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
      // 진영 앞 마당(15열)에서 북쪽 가운데 통로를 본다. 상대는 정면 210px.
      game.player
        ..position = Vector2(1085, 1575)
        ..angle = -pi / 2;
      await db.set('rooms/$code/states/b', state(1085, 1365));
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
      game.player.position = Vector2(1085, 1365);
      game.player.primary.ammo = 3;
      game.player.secondary.ammo = 0;
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
      final me = (x: game.player.position.x, y: game.player.position.y);
      expect(game.map.spawnsOf('A'), contains(me));
      // 부활하면 모든 무기 탄약이 가득.
      expect(game.player.primary.ammo, game.player.primary.weapon.magazine);
      expect(game.player.secondary.ammo, game.player.secondary.weapon.magazine);
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
