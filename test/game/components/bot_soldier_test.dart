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
    'bot walks the frontline map to a still player and shoots them',
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
      // 중앙 길(11열). 나는 남쪽을 봐서 봇을 안 쏜다. 봇은 북쪽, 둘 사이에 낮은 상자.
      game.player
        ..position = Vector2(805, 1575)
        ..angle = pi / 2;
      final b = botOf(game);
      b.body.position = Vector2(805, 1180);
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
}
