import 'dart:math';

import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/models/match_stats.dart';
import 'package:topsoldier/data/repositories/room_repository.dart';
import 'package:topsoldier/game/net/match_sync.dart';
import 'package:topsoldier/game/soldier_game.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/map_select.dart';
import 'package:topsoldier/rules/match.dart';
import 'package:topsoldier/rules/movement.dart';
import 'package:topsoldier/rules/spawn.dart';

import '../../fakes.dart';

const code = '2222';

/// 2대2 방(A: a(방장)·c, B: b·d)에서 [me] 시점. [db.serverTime]이 곧 내 시계.
GameTester<SoldierGame> tester2v2(
  FakeRtdbService db,
  String me, {
  int allyIndex = 0,
}) => GameTester(
  () => SoldierGame(
    random: Random(7),
    mapInfo: outpostMap,
    match: MatchSync(
      rooms: RoomRepository(db),
      code: code,
      uid: me,
      isHost: me == 'a',
      teamSize: 2,
      allyIndex: allyIndex,
      clock: () => db.serverTime,
    ),
  ),
  createGameWidget: (game) =>
      RiverpodAwareGameWidget(key: GlobalKey(), game: game),
  pumpWidget: (widget, tester) =>
      tester.pumpWidget(ProviderScope(child: widget)),
);

Map<String, Object?> state(double x, double y) => {
  'x': x,
  'y': y,
  'a': 1.0,
  'stance': 'standing',
  'up': 0.0,
  'weapon': 'pistol',
  't': {'.sv': 'timestamp'},
};

void main() {
  final db = FakeRtdbService();
  setUp(db.reset);

  Future<void> room({int endsIn = 60000}) async {
    await db.set('rooms/$code/meta', {
      'hostUid': 'a',
      'status': 'playing',
      'teamSize': 2,
      'endsAt': db.serverTime + endsIn,
    });
    for (final (id, team) in [('a', 'A'), ('b', 'B'), ('c', 'A'), ('d', 'B')]) {
      await db.set('rooms/$code/players/$id', {
        'name': id.toUpperCase(),
        'connected': true,
        'team': team,
      });
    }
  }

  Future<void> pump(SoldierGame game, WidgetTester tester, [int n = 3]) async {
    for (var i = 0; i < n; i++) {
      game.update(1 / 60);
      await tester.pump();
    }
  }

  ({MatchStats stats, bool opponentLeft})? ended;
  void listenEnd(SoldierGame game) {
    ended = null;
    game.match!.onMatchEnd = (stats, {required opponentLeft}) =>
        ended = (stats: stats, opponentLeft: opponentLeft);
  }

  tester2v2(db, 'a').testGameWidget(
    'allies are never targets (bullets pass through), enemies are; allies show '
    'on the minimap list',
    verify: (game, tester) async {
      await room();
      for (final (id, x) in [('b', 600.0), ('c', 700.0), ('d', 800.0)]) {
        await db.set('rooms/$code/states/$id', state(x, 500));
      }
      await pump(game, tester);
      db.serverTime += 500;
      await pump(game, tester);

      final m = game.match!;
      expect((m.teamSize, m.isAlly('c'), m.isAlly('b')), (2, true, false));
      expect(m.canHitRemote('c'), false);
      expect(m.canHitRemote('b'), true);
      final targets = {for (final t in game.hitTargets) (t.key as dynamic).uid};
      expect(targets, {'b', 'd'}); // 아군 c는 없다
      expect([for (final r in m.allies) r.uid], ['c']);
    },
  );

  tester2v2(db, 'a').testGameWidget(
    '2v2 ends at 12 team kills (11 keeps going), the host writes the winner',
    verify: (game, tester) async {
      await room();
      await pump(game, tester);
      await db.set('rooms/$code/score/A', 11);
      await pump(game, tester);
      expect(await db.get('rooms/$code/meta/status'), 'playing');
      await db.set('rooms/$code/score/A', 12);
      await pump(game, tester);
      expect(await db.get('rooms/$code/meta/status'), 'ended');
      expect(await db.get('rooms/$code/meta/winner'), 'A');
    },
  );

  tester2v2(db, 'a').testGameWidget(
    'time over: team scores compared, equal is a draw',
    verify: (game, tester) async {
      await room(endsIn: 1000);
      await pump(game, tester);
      await db.set('rooms/$code/score/A', 5);
      await db.set('rooms/$code/score/B', 5);
      db.serverTime += 1500;
      await pump(game, tester);
      expect(await db.get('rooms/$code/meta/winner'), 'draw');
    },
  );

  tester2v2(db, 'a').testGameWidget(
    'the result carries the team score (own : enemy) and nothing is 1v1-like',
    verify: (game, tester) async {
      await room();
      listenEnd(game);
      await pump(game, tester);
      await db.set('rooms/$code/score/A', 12);
      await db.set('rooms/$code/score/B', 9);
      await pump(game, tester);
      await pump(game, tester);
      expect(ended!.stats.result, MatchResult.win);
      expect((ended!.stats.ownScore, ended!.stats.enemyScore), (12, 9));
    },
  );

  tester2v2(db, 'a').testGameWidget(
    'one enemy leaves: the match goes on; both leave: win after the grace',
    verify: (game, tester) async {
      await room();
      listenEnd(game);
      await pump(game, tester);
      await db.set('rooms/$code/players/b/connected', false);
      db.serverTime += stuckGraceMs + 500;
      await pump(game, tester);
      expect(ended, isNull); // 2대1은 계속

      await db.set('rooms/$code/players/d/connected', false);
      await pump(game, tester);
      expect(ended, isNull); // 바로는 안 끝남
      db.serverTime += stuckGraceMs + 500;
      await pump(game, tester);
      expect(ended!.opponentLeft, true);
      expect(ended!.stats.result, MatchResult.win);
    },
  );

  tester2v2(db, 'b').testGameWidget(
    'the host left: the smallest uid still connected (b) finishes the match',
    verify: (game, tester) async {
      await room();
      await pump(game, tester);
      await db.set('rooms/$code/players/a/connected', false);
      await pump(game, tester);
      expect(game.match!.isFinisher, true);
      await db.set('rooms/$code/score/A', 12);
      await pump(game, tester);
      expect(await db.get('rooms/$code/meta/status'), 'ended');
      expect(await db.get('rooms/$code/meta/winner'), 'A');
    },
  );

  tester2v2(db, 'c').testGameWidget(
    'not the finisher: waits for the finisher, does not write the end',
    verify: (game, tester) async {
      await room();
      await pump(game, tester);
      await db.set('rooms/$code/players/a/connected', false);
      await pump(game, tester);
      expect(game.match!.isFinisher, false); // b가 담당
      await db.set('rooms/$code/score/A', 12);
      await pump(game, tester);
      expect(await db.get('rooms/$code/meta/status'), 'playing');
    },
  );

  for (final i in [0, 1]) {
    tester2v2(db, 'a', allyIndex: i).testGameWidget(
      'start spawn: ally #$i takes the #$i farthest spawn from the enemy side '
      '(no overlap)',
      verify: (game, tester) async {
        final spawns = game.map.spawnsOf('A');
        final enemies = game.map.spawnsOf('B');
        final want = startSpawn(spawns, enemies, allyIndex: i);
        expect(
          (game.player.position.x, game.player.position.y),
          (want.x, want.y),
        );
      },
    );
  }

  tester2v2(db, 'a').testGameWidget(
    'a player with no team (or a team other than A/B) is an enemy, never an '
    'ally: hittable, and counts as an opponent',
    verify: (game, tester) async {
      await room();
      await db.set('rooms/$code/players/e', {'name': 'E', 'connected': true});
      await db.set('rooms/$code/players/f', {
        'name': 'F',
        'connected': true,
        'team': 'X',
      });
      await pump(game, tester);
      final m = game.match!;
      expect(m.isAlly('e'), false);
      expect(m.isAlly('f'), false);
      expect(m.canHitRemote('e'), true);
      expect(m.canHitRemote('f'), true);
      expect(m.isAlly('c'), true); // 진짜 아군은 그대로
    },
  );

  test('allies #0 and #1 start on different spawns', () {
    // 아군 둘이 같은 곳에서 시작하지 않는다는 규칙 확인(맵과 무관).
    final spawns = <Vec>[
      (x: 0.0, y: 0.0),
      (x: 50.0, y: 0.0),
      (x: 100.0, y: 0.0),
    ];
    final enemies = <Vec>[(x: 0.0, y: 500.0)];
    expect(
      startSpawn(spawns, enemies, allyIndex: 0) ==
          startSpawn(spawns, enemies, allyIndex: 1),
      false,
    );
  });

  test('the 2v2 win line is 12 and the 1v1 one stays 7', () {
    expect((killsToWin2v2, killsToWin), (12, 7));
  });
}
