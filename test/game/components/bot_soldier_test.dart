import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/models/room.dart';
import 'package:topsoldier/data/repositories/room_repository.dart';
import 'package:topsoldier/game/components/bot_soldier.dart';
import 'package:topsoldier/game/net/match_sync.dart';
import 'package:topsoldier/game/soldier_game.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/cover.dart';

import '../../fakes.dart';

const code = '1234';
const bot = RoomRepository.botUid;

/// 나는 'a'(A팀), 상대는 보통 봇. [db.serverTime]이 시계.
GameTester<SoldierGame> botTester(FakeRtdbService db) => GameTester(
  () => SoldierGame(
    random: Random(7),
    bot: BotDifficulty.normal,
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

void main() {
  final db = FakeRtdbService();
  setUp(db.reset);

  BotSoldier botOf(SoldierGame g) => g.children.whereType<BotSoldier>().single;

  /// [seconds]만큼 60fps로 돌린다. 서버 시간도 같이 간다.
  Future<void> run(
    SoldierGame game,
    WidgetTester tester,
    double seconds, {
    bool Function()? until,
  }) async {
    for (var i = 0; i < seconds * 60; i++) {
      db.serverTime += 16;
      game.update(1 / 60);
      if (i % 6 == 0) await tester.pump();
      if (until?.call() ?? false) return;
    }
  }

  Map<Object?, Object?> room() =>
      ((db.root['rooms'] as Map?)?[code] as Map?) ?? const {};

  double hpOf(String id) =>
      (((room()['hp'] as Map?)?[id] as Map?)?['value'] as num?)?.toDouble() ??
      -1;

  botTester(db).testGameWidget(
    'bot spawns at a B spawn, writes full hp and its state',
    verify: (game, tester) async {
      await run(game, tester, 0.5);
      final b = botOf(game).body.position;
      expect(
        game.map
            .spawnsOf(RoomMeta.teamB)
            .any((s) => (s.x - b.x).abs() < 300 && (s.y - b.y).abs() < 300),
        isTrue,
      );
      expect(hpOf(bot), basicSoldier.hp);
      expect((room()['states'] as Map?)?[bot], isNotNull);
      // 상대(RemotePlayer)로 보인다.
      expect(game.match!.remotes.keys, contains(bot));
    },
  );

  botTester(db).testGameWidget(
    'bot walks the map to a still player and shoots them',
    verify: (game, tester) async {
      final start = botOf(game).body.position.clone();
      await run(
        game,
        tester,
        40,
        until: () => hpOf('a') > 0 && hpOf('a') < basicSoldier.hp,
      );
      expect(botOf(game).body.position.distanceTo(start), greaterThan(500));
      expect(hpOf('a'), lessThan(basicSoldier.hp));
    },
  );

  botTester(db).testGameWidget(
    'low hp while fighting: hides crouched behind a low crate',
    verify: (game, tester) async {
      await run(game, tester, 0.1);
      // 가운데 통로(15열). 나는 남쪽을 봐서 봇을 안 쏜다. 봇은 북쪽 광장, 둘 사이에
      // 광장 한가운데 긴 상자.
      game.player
        ..position = Vector2(1085, 1365)
        ..angle = pi / 2;
      final b = botOf(game);
      b.body.position = Vector2(1085, 945);
      await RoomRepository(db)
          .setHp(code, bot, const NetHp(value: 30, protectedUntil: 0));
      await run(game, tester, 6, until: () => b.body.body.crouching);
      expect(b.body.body.crouching, isTrue);
      expect(
        hiddenBehindLowCover(
          b.body.coverBody,
          game.player.coverBody,
          game.map.lowCrates,
        ),
        isTrue,
      );

      // 재장전이 끝나고 최소 시간이 지나면 다시 일어나 싸운다.
      await run(game, tester, botCoverHold + 3, until: () => b.body.firing);
      expect(b.body.body.crouching, isFalse);
      expect(b.body.firing, isTrue);
    },
  );

  botTester(db).testGameWidget(
    'bot carries its difficulty weapon (normal = M249)',
    verify: (game, tester) async {
      await run(game, tester, 0.1);
      expect(
        botOf(game).body.primary.weapon,
        botLevels[BotDifficulty.normal]!.weapon,
      );
      expect(botLevels[BotDifficulty.normal]!.weapon, rifleHeavy);
    },
  );

  botTester(db).testGameWidget(
    'killed bot comes back after the respawn delay with full hp',
    verify: (game, tester) async {
      await run(game, tester, 0.5);
      await RoomRepository(db)
          .setHp(code, bot, const NetHp(value: 0, protectedUntil: 0));
      await run(game, tester, respawnDelay - 1);
      expect(hpOf(bot), 0);
      await run(game, tester, 1.5);
      expect(hpOf(bot), basicSoldier.hp);
    },
  );

  testWidgets('hard bot hits a still player far more than easy', (
    tester,
  ) async {
    // 가운데 길 340px(진영 앞 마당 → 통로 → 광장), 나는 가만히(봇을 안 봄). 봇·나 체력은 안 닳게 채우며 10초 누적 데미지.
    Future<double> damage(BotDifficulty d, int seed) async {
      final db = FakeRtdbService();
      final repo = RoomRepository(db);
      final game = SoldierGame(
        random: Random(seed),
        bot: d,
        match: MatchSync(
          rooms: repo,
          code: code,
          uid: 'a',
          isHost: true,
          clock: () => db.serverTime,
        ),
      );
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            child: RiverpodAwareGameWidget<SoldierGame>(
              key: GlobalKey(),
              game: game,
            ),
          ),
        );
        await tester.pump();
      });
      await run(game, tester, 0.1);
      game.player
        ..position = Vector2(1085, 1575)
        ..angle = pi / 2;
      botOf(game).body.position = Vector2(1085, 1235);
      await repo.setHp(code, bot, const NetHp(value: 1e9, protectedUntil: 0));
      const full = 1e6;
      var total = 0.0;
      for (var i = 0; i < 600; i++) {
        await repo.setHp(
          code,
          'a',
          const NetHp(value: full, protectedUntil: 0),
        );
        db.serverTime += 16;
        game.update(1 / 60);
        if (i % 3 == 0) await tester.pump();
        final hp =
            (((db.root['rooms']! as Map)[code] as Map)['hp'] as Map)['a'];
        total += full - ((hp as Map)['value'] as num);
      }
      return total;
    }

    var easy = 0.0, hard = 0.0;
    for (final seed in [1, 2, 3]) {
      easy += await damage(BotDifficulty.easy, seed);
      hard += await damage(BotDifficulty.hard, seed);
    }
    expect(easy, greaterThan(0));
    expect(hard, greaterThan(easy * 2), reason: 'easy $easy, hard $hard');
  });
}
