import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/models/match_stats.dart';
import 'package:topsoldier/data/models/room.dart';
import 'package:topsoldier/data/repositories/room_repository.dart';
import 'package:topsoldier/game/components/bot_soldier.dart';
import 'package:topsoldier/game/net/match_sync.dart';
import 'package:topsoldier/game/soldier_game.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/match.dart';

import '../../fakes.dart';

const ally = RoomRepository.allyBotUid;
const enemy1 = RoomRepository.botUid;
const enemy2 = RoomRepository.enemyBot2Uid;

/// 봇전 2대2 방(나 + 아군 봇 vs 적 봇 둘)을 가짜 DB에 만들고 게임을 띄운다.
/// 게임 맵은 기본 duel(곧은 길이 있어 좌표를 정하기 쉽다). 규칙은 맵과 무관하다.
Future<({SoldierGame game, RoomRepository repo, String code})> setup(
  WidgetTester tester,
  FakeRtdbService db, {
  int seed = 7,
  BotDifficulty level = BotDifficulty.normal,
}) async {
  final repo = RoomRepository(db, clock: () => db.serverTime);
  final code = await repo.createRoom(uid: 'a', name: 'Me', teamSize: 2);
  await repo.joinRoom(code, uid: enemy1, name: 'BOT');
  await repo.joinRoom(code, uid: ally, name: 'BOT 아군');
  await repo.joinRoom(code, uid: enemy2, name: 'BOT 2');
  await repo.start(code, durationMs: matchDurationMs);
  final game = SoldierGame(
    random: Random(seed),
    bot: level,
    match: MatchSync(
      rooms: repo,
      code: code,
      uid: 'a',
      isHost: true,
      teamSize: 2,
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
  return (game: game, repo: repo, code: code);
}

void main() {
  final db = FakeRtdbService();
  setUp(db.reset);

  BotSoldier botOf(SoldierGame g, String uid) =>
      g.children.whereType<BotSoldier>().firstWhere((b) => b.uid == uid);

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

  double hpOf(String code, String id) =>
      ((((db.root['rooms']! as Map)[code] as Map)['hp'] as Map?)?[id]
              as Map?)?['value']
          as double? ??
      -1;

  testWidgets('three bots join: ally on my team, two enemies on the other', (
    tester,
  ) async {
    final s = await setup(tester, db);
    await run(s.game, tester, 0.5);
    final bots = s.game.children.whereType<BotSoldier>();
    expect(
      bots.map((b) => (b.uid, b.team)),
      unorderedEquals([
        (enemy1, RoomMeta.teamB),
        (ally, RoomMeta.teamA),
        (enemy2, RoomMeta.teamB),
      ]),
    );
    final m = s.game.match!;
    expect(m.isAlly(ally), isTrue);
    expect(m.isAlly(enemy1) || m.isAlly(enemy2), isFalse);
    expect(m.remotes.keys, containsAll([ally, enemy1, enemy2]));
    // 각자 자기 팀 스폰 근처에 서고 체력이 가득.
    for (final b in bots) {
      final p = b.body.position;
      expect(
        s.game.map
            .spawnsOf(b.team)
            .any((sp) => (sp.x - p.x).abs() < 300 && (sp.y - p.y).abs() < 300),
        isTrue,
        reason: b.uid,
      );
      expect(hpOf(s.code, b.uid), basicSoldier.hp);
    }
    // 같은 팀 봇과 나는 시작 스폰이 겹치지 않는다.
    expect(
      botOf(s.game, ally).body.position.distanceTo(s.game.player.position),
      greaterThan(30),
    );
  });

  testWidgets('bullets: allies pass through, enemies are hittable', (
    tester,
  ) async {
    final s = await setup(tester, db);
    await run(s.game, tester, 0.5);
    List<Object> keysOf(String uid) => [
      for (final t in botOf(s.game, uid).targets()) t.key,
    ];
    final e1 = botOf(s.game, enemy1), e2 = botOf(s.game, enemy2);
    final a = botOf(s.game, ally);
    // 아군 봇의 총알: 적 봇 둘만. 나는 못 맞힌다.
    expect(keysOf(ally), unorderedEquals([e1, e2]));
    // 적 봇의 총알: 나와 아군 봇. 같은 편 적 봇은 못 맞힌다.
    expect(keysOf(enemy1), unorderedEquals([s.game.player, a]));
    expect(keysOf(enemy2), unorderedEquals([s.game.player, a]));
  });

  testWidgets('ally bot fights an enemy bot, enemy bots go for the ally too', (
    tester,
  ) async {
    final s = await setup(tester, db, level: BotDifficulty.hard);
    await run(s.game, tester, 0.2);
    // duel 7열의 곧은 길(높은 벽·상자 없음): 아군 봇과 적 봇 하나가 마주 본다.
    // 나와 다른 적 봇은 멀리(서로 안 보임).
    botOf(s.game, ally).body.position = Vector2(525, 385);
    botOf(s.game, enemy1).body.position = Vector2(525, 735);
    botOf(s.game, enemy2).body.position = Vector2(175, 2000);
    s.game.player.position = Vector2(175, 60);
    await run(
      s.game,
      tester,
      15,
      until: () =>
          hpOf(s.code, enemy1) < basicSoldier.hp &&
          hpOf(s.code, ally) < basicSoldier.hp,
    );
    expect(
      hpOf(s.code, enemy1),
      lessThan(basicSoldier.hp),
      reason: '아군 봇이 적 봇을 쐈다',
    );
    expect(
      hpOf(s.code, ally),
      lessThan(basicSoldier.hp),
      reason: '적 봇이 아군 봇을 쐈다',
    );
    expect(hpOf(s.code, 'a'), basicSoldier.hp, reason: '나는 안 맞았다');
  });

  testWidgets('team score 12 ends the match with a win for my team', (
    tester,
  ) async {
    final s = await setup(tester, db);
    MatchStats? ended;
    s.game.match!.onMatchEnd = (stats, {required opponentLeft}) =>
        ended = stats;
    await run(s.game, tester, 0.3);
    for (var i = 0; i < killsToWin2v2 - 1; i++) {
      await s.repo.addScore(s.code, RoomMeta.teamA);
    }
    await run(s.game, tester, 0.5);
    expect(ended, isNull, reason: '11킬은 아직');
    await s.repo.addScore(s.code, RoomMeta.teamA);
    await run(s.game, tester, 1, until: () => ended != null);
    expect(ended?.result, MatchResult.win);
    expect((ended?.ownScore, ended?.enemyScore), (killsToWin2v2, 0));
  });

  testWidgets('frame cost with four fighters (10 s)', (tester) async {
    final s = await setup(tester, db, level: BotDifficulty.hard);
    await run(s.game, tester, 0.5);
    final times = <int>[];
    final sw = Stopwatch();
    for (var i = 0; i < 600; i++) {
      db.serverTime += 16;
      sw
        ..reset()
        ..start();
      s.game.update(1 / 60);
      sw.stop();
      times.add(sw.elapsedMicroseconds);
      if (i % 6 == 0) await tester.pump();
    }
    final avg = times.reduce((a, b) => a + b) / times.length / 1000;
    final worst = times.reduce(max) / 1000;
    debugPrint(
      'PERF 2v2 update(): avg ${avg.toStringAsFixed(3)} ms, '
      'max ${worst.toStringAsFixed(3)} ms (60fps budget 16.7 ms)',
    );
    expect(avg, lessThan(8));
  });
}
