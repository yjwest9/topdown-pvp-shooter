import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/models/room.dart';
import 'package:topsoldier/data/repositories/room_repository.dart';
import 'package:topsoldier/data/repositories/sound_repository.dart';
import 'package:topsoldier/game/components/bot_soldier.dart';
import 'package:topsoldier/game/net/match_sync.dart';
import 'package:topsoldier/game/soldier_game.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/combat.dart';

import '../fakes.dart';

const code = '1234';
const _fires = {
  'fire_rifle.ogg',
  'fire_sniper.ogg',
  'fire_shotgun.ogg',
  'fire_pistol.ogg',
};

GameTester<SoldierGame> _tester(SoldierGame Function() make) => GameTester(
  make,
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
  final sound = FakeSoundService();
  final db = FakeRtdbService();
  setUp(() {
    sound.plays.clear();
    db.reset();
  });

  // ------------------------------------------------------------- 훈련소(오프라인)

  /// 수동 발사: 표적이 앞에 있어도 저절로 쏘지 않는다(쏘는 건 fireButtonHeld로).
  GameTester<SoldierGame> training() => _tester(
    () => SoldierGame(
      random: Random(7),
      sound: SoundRepository(sound),
      primaryFireMode: FireMode.manual,
    ),
  );

  for (final (weapon, file) in [
    (rifleStandard, 'fire_rifle.ogg'),
    (rifleHeavy, 'fire_rifle.ogg'), // 중기관총형도 라이플 소리
    (sniperBolt, 'fire_sniper.ogg'),
    (shotgunPump, 'fire_shotgun.ogg'), // 펠릿 8개여도 소리는 한 번
  ]) {
    training().testGameWidget(
      'one shot of ${weapon.id} plays $file once, at full volume',
      verify: (game, tester) async {
        place(game, 0);
        game.player.selectPrimary(weapon);
        game.fireButtonHeld = true;
        game.update(1 / 60);
        game.update(1 / 60); // 연사 간격 안: 두 번째 발은 없다
        expect(sound.plays, [(file: file, volume: 1.0)]);
      },
    );
  }

  training().testGameWidget(
    'secondary pistol plays fire_pistol.ogg',
    verify: (game, tester) async {
      place(game, 0);
      game.player.selectSlot(primary: false);
      game.fireButtonHeld = true;
      game.update(1 / 60);
      expect(sound.files, ['fire_pistol.ogg']);
    },
  );

  training().testGameWidget(
    'holding fire plays one sound per bullet fired',
    verify: (game, tester) async {
      place(game, 0);
      game.fireButtonHeld = true;
      final ammo = game.player.weapon.ammo;
      for (var i = 0; i < 60; i++) {
        game.update(1 / 60);
      }
      final shots = ammo - game.player.weapon.ammo;
      expect(shots, greaterThan(3));
      expect(sound.files.where(_fires.contains), hasLength(shots));
    },
  );

  training().testGameWidget(
    'reload sound plays once when a reload starts (button or empty magazine)',
    verify: (game, tester) async {
      place(game, 0);
      game.player.weapon.ammo = 5;
      game.update(1 / 60);
      expect(sound.files, isEmpty); // 탄이 남아 있고 장전 안 함

      game.player.weapon.reload(); // RELOAD 버튼·R 키
      game.update(1 / 60);
      game.update(1 / 60);
      expect(sound.files, ['reload.ogg']); // 재장전 중에는 다시 안 남

      while (game.player.weapon.reloading) {
        game.update(0.1);
      }
      game.player.weapon.ammo = 0; // 탄이 떨어져 자동 재장전
      game.update(1 / 60);
      expect(sound.files, ['reload.ogg', 'reload.ogg']);
    },
  );

  training().testGameWidget(
    'my hit makes the hit sound, killing makes the kill sound',
    verify: (game, tester) async {
      place(game, -pi / 2); // 표적 ①은 300px 앞
      game.fireButtonHeld = true;
      final dummy = game.dummies[0];
      for (var i = 0; i < 120 && dummy.hp == 100; i++) {
        game.update(1 / 60);
      }
      expect(dummy.hp, lessThan(100));
      expect(sound.files.where((f) => f == 'hit.ogg'), hasLength(1));
      expect(sound.files, isNot(contains('kill.ogg')));

      game.hitTargets.first.onHit(
        const HitResult(miss: false, crit: false, damage: 999),
        rifleStandard,
      );
      expect(sound.files.where((f) => f == 'kill.ogg'), hasLength(1));
    },
  );

  training().testGameWidget(
    'sound off: nothing is played; back on: sound is back',
    verify: (game, tester) async {
      game.soundEnabled = false;
      place(game, -pi / 2);
      game.fireButtonHeld = true;
      game.player.weapon.ammo = 1; // 쏘고 나면 자동 재장전
      for (var i = 0; i < 90; i++) {
        game.update(1 / 60);
      }
      game.confirmKill('표적');
      game.playEnemyShot(rifleStandard, game.player.position);
      expect(sound.plays, isEmpty);

      game.soundEnabled = true;
      game.confirmKill('표적');
      expect(sound.files, ['kill.ogg']);
    },
  );

  _tester(
    () => SoldierGame(
      random: Random(7),
      sound: SoundRepository(sound),
      primaryFireMode: FireMode.manual,
      soundEnabled: false,
    ),
  ).testGameWidget(
    'a game created with sound off stays silent',
    verify: (game, tester) async {
      place(game, 0);
      game.fireButtonHeld = true;
      game.update(1 / 60);
      expect(sound.plays, isEmpty);
    },
  );

  training().testGameWidget(
    'enemy shot is heard at half volume only when the enemy is on screen',
    verify: (game, tester) async {
      place(game, -pi / 2); // 정면은 위(-y)
      game.update(1 / 60);
      final p = game.player.position;
      game.playEnemyShot(rifleStandard, p + Vector2(0, -150)); // 앞
      game.playEnemyShot(sniperBolt, p + Vector2(0, -3000)); // 화면 밖
      game.playEnemyShot(shotgunPump, p + Vector2(3000, 0)); // 화면 밖
      expect(sound.plays, [(file: 'fire_rifle.ogg', volume: enemyShotVolume)]);
    },
  );

  // ------------------------------------------------------------- 1대1(PvP)

  GameTester<SoldierGame> online() => _tester(
    () => SoldierGame(
      random: Random(7),
      sound: SoundRepository(sound),
      match: MatchSync(
        rooms: RoomRepository(db),
        code: code,
        uid: 'a',
        isHost: true,
        clock: () => db.serverTime,
      ),
    ),
  );

  Future<void> shot(String weapon, Vector2 at) => db.push('rooms/$code/shots', {
    'by': 'b',
    'x': at.x,
    'y': at.y,
    'a': 0.0,
    'weapon': weapon,
    't': {'.sv': 'timestamp'},
  });

  /// 쏜 시각이 재생 시각(서버 시간 − 100ms)을 지나 상대 총알이 내 화면에 나오게.
  Future<void> shown(WidgetTester tester, SoldierGame game) async {
    db.serverTime += 200;
    await tester.pump();
    game.update(1 / 60);
    await tester.pump();
  }

  online().testGameWidget(
    "opponent's shot: heard at half volume on my screen, silent off screen",
    verify: (game, tester) async {
      place(game, -pi / 2);
      game.update(1 / 60);
      final p = game.player.position;
      await shot('rifle_standard', p + Vector2(0, -120));
      await shot('sniper_bolt', p + Vector2(0, -4000));
      await shown(tester, game);
      expect(sound.plays, [(file: 'fire_rifle.ogg', volume: enemyShotVolume)]);
    },
  );

  online().testGameWidget(
    "opponent's shotgun volley (8 pellets) is one sound",
    verify: (game, tester) async {
      place(game, -pi / 2);
      game.update(1 / 60);
      for (var i = 0; i < 8; i++) {
        await shot('shotgun_pump', game.player.position + Vector2(0, -100));
      }
      await shown(tester, game);
      expect(sound.plays, [
        (file: 'fire_shotgun.ogg', volume: enemyShotVolume),
      ]);
    },
  );

  Future<void> setHp(String id, double value) =>
      db.set('rooms/$code/hp/$id', {'value': value, 'protectedUntil': 0});

  online().testGameWidget(
    'getting hit plays the hurt sound; getting healed does not',
    verify: (game, tester) async {
      await setHp('a', 100);
      await tester.pump();
      await setHp('a', 60);
      await tester.pump();
      expect(sound.files, ['hurt.ogg']);
      await setHp('a', 100); // 부활
      await tester.pump();
      expect(sound.files, ['hurt.ogg']);
    },
  );

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

  online().testGameWidget(
    'match end: win sound when I win',
    verify: (game, tester) async {
      await bothPlaying(endsIn: 60000);
      await db.set('rooms/$code/score/A', killsToWin);
      await tester.pump();
      game.update(1 / 60);
      await tester.pump();
      expect(sound.files.where((f) => f == 'win.ogg'), hasLength(1));
      expect(sound.files, isNot(contains('lose.ogg')));
    },
  );

  online().testGameWidget(
    'match end: lose sound when I lose',
    verify: (game, tester) async {
      await bothPlaying(endsIn: 60000);
      await db.set('rooms/$code/score/B', killsToWin);
      await tester.pump();
      game.update(1 / 60);
      await tester.pump();
      expect(sound.files.where((f) => f == 'lose.ogg'), hasLength(1));
      expect(sound.files, isNot(contains('win.ogg')));
    },
  );

  online().testGameWidget(
    'match end: a draw has no win/lose sound',
    verify: (game, tester) async {
      await bothPlaying(endsIn: 1000);
      await tester.pump();
      game.update(1 / 60);
      db.serverTime += 1000;
      game.update(1 / 60);
      await tester.pump();
      expect(await db.get('rooms/$code/meta/winner'), 'draw');
      expect(sound.files, isNot(contains('win.ogg')));
      expect(sound.files, isNot(contains('lose.ogg')));
    },
  );

  online().testGameWidget(
    'my hit that kills in PvP plays the kill sound',
    verify: (game, tester) async {
      await setHp('b', 10);
      game.match!.hit(
        'b',
        const HitResult(miss: false, crit: false, damage: 13),
        rifleStandard,
      );
      await tester.pump();
      await tester.pump();
      expect(sound.files, contains('kill.ogg'));
    },
  );

  // ------------------------------------------------------------- 봇전

  _tester(
    () => SoldierGame(
      random: Random(7),
      sound: SoundRepository(sound),
      bot: BotDifficulty.normal,
      match: MatchSync(
        rooms: RoomRepository(db),
        code: code,
        uid: 'a',
        isHost: true,
        clock: () => db.serverTime,
      ),
    ),
  ).testGameWidget(
    'bot shots: half volume when the bot is on screen, silent when behind me',
    verify: (game, tester) async {
      final repo = RoomRepository(db);
      final bot = game.children.whereType<BotSoldier>().single;
      Future<int> botShots({required double myAngle}) async {
        sound.plays.clear();
        game.player
          ..position = Vector2(1085, 1575)
          ..angle = myAngle;
        bot.body.position = Vector2(1085, 1235); // 내 북쪽 340px
        bot.body.weapon.ammo = bot.body.weapon.weapon.magazine;
        final before = bot.body.weapon.ammo;
        await repo.setHp(code, 'a', const NetHp(value: 1e9, protectedUntil: 0));
        await repo.setHp(
          code,
          RoomRepository.botUid,
          const NetHp(value: 1e9, protectedUntil: 0),
        );
        for (var i = 0; i < 240; i++) {
          db.serverTime += 16;
          game.update(1 / 60);
          if (i % 6 == 0) await tester.pump();
        }
        return before - bot.body.weapon.ammo; // 봇이 쏜 수
      }

      // 북쪽을 보고 있으면 봇이 정면 340px: 화면 안.
      final fired = await botShots(myAngle: -pi / 2);
      expect(fired, greaterThan(0));
      final heard = sound.plays.where((p) => _fires.contains(p.file));
      expect(heard, isNotEmpty);
      expect(heard.map((p) => p.volume).toSet(), {enemyShotVolume});

      // 남쪽을 보면 봇은 내 뒤 340px: 화면 밖(뒤는 204px까지만 보임).
      final firedBehind = await botShots(myAngle: pi / 2);
      expect(firedBehind, greaterThan(0));
      expect(sound.files.where(_fires.contains), isEmpty);
    },
  );
}
