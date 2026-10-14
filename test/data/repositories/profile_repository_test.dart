import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/models/profile.dart';
import 'package:topsoldier/data/repositories/profile_repository.dart';

import '../../fakes.dart';

void main() {
  test('create → watch shows a fresh level 1 profile', () async {
    final db = FakeRtdbService();
    final repo = ProfileRepository(db);
    expect(await repo.watch('u').first, isNull);

    await repo.create('u', '솔저');

    final p = (await repo.watch('u').first)!;
    expect((p.nickname, p.level, p.exp, p.gold, p.diamond), ('솔저', 1, 0, 0, 0));
    expect(await db.get('users/u/createdAt'), db.serverTime);
  });

  test('the same matchId is added only once', () async {
    final repo = ProfileRepository(FakeRtdbService());
    await repo.create('u', 'A');

    final first = await repo.applyMatch(
      'u',
      'room1-100',
      (p) => p.copyWith(gold: p.gold + 5000, matches: p.matches + 1),
    );
    final again = await repo.applyMatch(
      'u',
      'room1-100',
      (p) => p.copyWith(gold: p.gold + 5000, matches: p.matches + 1),
    );

    expect(first!.before.gold, 0);
    expect(first.after.gold, 5000);
    expect(again, isNull);
    final p = (await repo.watch('u').first)!;
    expect((p.gold, p.matches), (5000, 1));

    await repo.applyMatch(
      'u',
      'room1-200',
      (p) => p.copyWith(gold: p.gold + 1),
    );
    expect((await repo.watch('u').first)!.gold, 5001); // 다른 매치는 더해짐
  });

  test('no profile yet → nothing is written', () async {
    final db = FakeRtdbService();
    final r = await ProfileRepository(db)
        .applyMatch('u', 'm', (p) => p.copyWith(gold: 1));
    expect(r, isNull);
    expect(await db.get('users/u'), isNull);
  });

  test('nickname change keeps the rest', () async {
    final repo = ProfileRepository(FakeRtdbService());
    await repo.create('u', 'A');
    await repo.applyMatch('u', 'm', (p) => p.copyWith(gold: 10));
    await repo.setNickname('u', '새이름');
    final p = (await repo.watch('u').first)!;
    expect((p.nickname, p.gold), ('새이름', 10));
  });

  group('weapons', () {
    Future<ProfileRepository> withGold(FakeRtdbService db, int gold) async {
      final repo = ProfileRepository(db);
      await repo.create('u', 'A');
      await db.update('users/u', {'gold': gold});
      return repo;
    }

    test(
      'starter weapons: granted once, equipped (existing user too)',
      () async {
        final db = FakeRtdbService();
        final repo = await withGold(db, 777); // 이미 플레이하던 유저
        await repo.grantStarter(
          'u',
          primary: 'rifle_standard',
          secondary: 'pistol',
        );
        await repo.grantStarter(
          'u',
          primary: 'rifle_standard',
          secondary: 'pistol',
        );

        final p = (await repo.watch('u').first)!;
        expect(
          p.weapons.map((w) => w.weaponId),
          unorderedEquals(['rifle_standard', 'pistol']),
        );
        expect(p.byId(p.primaryId)!.weaponId, 'rifle_standard');
        expect(p.byId(p.secondaryId)!.weaponId, 'pistol');
        expect(p.weapons.first.grade, 'E');
        expect(p.gold, 777);
      },
    );

    test('buy: enough gold → weapon added and gold taken', () async {
      final db = FakeRtdbService();
      final repo = await withGold(db, 25000);
      expect(await repo.buy('u', 'sniper_bolt', 20000), true);

      final p = (await repo.watch('u').first)!;
      expect(p.gold, 5000);
      expect(p.owned('sniper_bolt')!.level, 0);
      expect(
        await db.get(
          'users/u/weapons/${p.owned('sniper_bolt')!.id}/acquiredAt',
        ),
        isNotNull,
      );
    });

    test('buy: not enough gold → nothing changes', () async {
      final db = FakeRtdbService();
      final repo = await withGold(db, 19999);
      expect(await repo.buy('u', 'sniper_bolt', 20000), false);
      final p = (await repo.watch('u').first)!;
      expect(p.gold, 19999);
      expect(p.weapons, isEmpty);
    });

    test('buy: already owned → nothing changes', () async {
      final db = FakeRtdbService();
      final repo = await withGold(db, 50000);
      await repo.buy('u', 'sniper_bolt', 20000);
      expect(await repo.buy('u', 'sniper_bolt', 20000), false);
      final p = (await repo.watch('u').first)!;
      expect((p.gold, p.weapons.length), (30000, 1));
    });

    test('equip changes the loadout slot', () async {
      final db = FakeRtdbService();
      final repo = await withGold(db, 20000);
      await repo.grantStarter(
        'u',
        primary: 'rifle_standard',
        secondary: 'pistol',
      );
      await repo.buy('u', 'shotgun_pump', 20000);
      var p = (await repo.watch('u').first)!;
      await repo.equip('u', p.owned('shotgun_pump')!.id, primary: true);

      p = (await repo.watch('u').first)!;
      expect(p.byId(p.primaryId)!.weaponId, 'shotgun_pump');
      expect(p.byId(p.secondaryId)!.weaponId, 'pistol');
    });

    group('upgrade', () {
      Future<(ProfileRepository, String)> owned(
        FakeRtdbService db,
        int gold,
      ) async {
        final repo = await withGold(db, gold);
        await repo.grantStarter(
          'u',
          primary: 'rifle_standard',
          secondary: 'pistol',
        );
        final p = (await repo.watch('u').first)!;
        return (repo, p.owned('rifle_standard')!.id);
      }

      Future<(int, int)> goldAndLevel(ProfileRepository repo) async {
        final p = (await repo.watch('u').first)!;
        return (p.gold, p.owned('rifle_standard')!.level);
      }

      test('success: gold taken, level +1', () async {
        final db = FakeRtdbService();
        final (repo, id) = await owned(db, 5000);
        expect(
          await repo.upgrade('u', id, fromLevel: 0, cost: 2000, success: true),
          true,
        );
        expect(await goldAndLevel(repo), (3000, 1));
      });

      test('fail: only gold taken', () async {
        final db = FakeRtdbService();
        final (repo, id) = await owned(db, 5000);
        expect(
          await repo.upgrade('u', id, fromLevel: 0, cost: 2000, success: false),
          true,
        );
        expect(await goldAndLevel(repo), (3000, 0));
      });

      test('not enough gold: nothing changes', () async {
        final db = FakeRtdbService();
        final (repo, id) = await owned(db, 1999);
        expect(
          await repo.upgrade('u', id, fromLevel: 0, cost: 2000, success: true),
          false,
        );
        expect(await goldAndLevel(repo), (1999, 0));
      });

      test(
        'the same upgrade twice is applied once (level already moved)',
        () async {
          final db = FakeRtdbService();
          final (repo, id) = await owned(db, 10000);
          for (var i = 0; i < 2; i++) {
            await repo.upgrade(
              'u',
              id,
              fromLevel: 0,
              cost: 2000,
              success: true,
            );
          }
          expect(await goldAndLevel(repo), (8000, 1));
        },
      );

      test('a rerun of the transaction keeps the same result', () async {
        // 실제 RTDB는 서버 값이 다르면 같은 함수를 다시 부른다. 성공 여부는 밖에서 정해져
        // 있으니 다시 돌아도 같은 결과, 한 번만 적용.
        final db = FakeRtdbService()..rerunTransactions = true;
        final (repo, id) = await owned(db, 10000);
        await repo.upgrade('u', id, fromLevel: 0, cost: 2000, success: true);
        expect(await goldAndLevel(repo), (8000, 1));
      });
    });

    test('match reward keeps weapons and loadout', () async {
      final db = FakeRtdbService();
      final repo = await withGold(db, 0);
      await repo.grantStarter(
        'u',
        primary: 'rifle_standard',
        secondary: 'pistol',
      );
      await repo.applyMatch('u', 'm1', (p) => p.copyWith(gold: p.gold + 5000));
      final p = (await repo.watch('u').first)!;
      expect((p.gold, p.weapons.length, p.hasLoadout), (5000, 2, true));
    });
  });

  group('shop (decisions 9장)', () {
    Future<ProfileRepository> withGold(FakeRtdbService db, int gold) async {
      final repo = ProfileRepository(db);
      await repo.create('u', 'A');
      await db.update('users/u', {'gold': gold, 'diamond': 7});
      return repo;
    }

    test('ad reward: gold +10,000 and lastAdAt = server time', () async {
      final db = FakeRtdbService()..serverTime = 5000;
      final repo = await withGold(db, 300);
      await repo.rewardAd('u', 10000);
      final p = (await repo.watch('u').first)!;
      expect((p.gold, p.lastAdAt), (10300, 5000));
    });

    ({int gold, int diamond})? swap(int gold, int diamond) =>
        gold < 100000 ? null : (gold: gold - 100000, diamond: diamond + 100);

    test('exchange: gold −100,000, diamond +100, lastAdAt kept', () async {
      final db = FakeRtdbService();
      final repo = await withGold(db, 250000);
      await repo.rewardAd('u', 0);
      expect(await repo.exchange('u', swap), true);
      final p = (await repo.watch('u').first)!;
      expect((p.gold, p.diamond, p.lastAdAt), (150000, 107, db.serverTime));
    });

    test('exchange with too little gold changes nothing', () async {
      final db = FakeRtdbService();
      final repo = await withGold(db, 99999);
      final before = await db.get('users/u');
      expect(await repo.exchange('u', swap), false);
      expect(await db.get('users/u'), before);
    });
  });

  group('characters (decisions 8장)', () {
    Future<ProfileRepository> start(
      FakeRtdbService db, {
      int gold = 0,
      int diamond = 0,
    }) async {
      final repo = ProfileRepository(db);
      await repo.create('u', 'A');
      await db.update('users/u', {'gold': gold, 'diamond': diamond});
      await repo.grantStarterCharacter('u', id: 'basic');
      return repo;
    }

    Future<Profile> read(ProfileRepository repo) async =>
        (await repo.watch('u').first)!;

    test('starter: basic +0 granted once and equipped, kept as is', () async {
      final db = FakeRtdbService();
      final repo = await start(db);
      await db.set('users/u/characters/basic/level', 2);
      await repo.grantStarterCharacter('u', id: 'basic');
      final p = await read(repo);
      expect(p.characters, {'basic': 2});
      expect(p.equippedCharacter, 'basic');
    });

    test('old profile without characters reads as basic equipped', () async {
      final repo = ProfileRepository(FakeRtdbService());
      await repo.create('u', 'A');
      final p = await read(repo);
      expect(p.characters, isEmpty);
      expect(p.equippedCharacter, 'basic');
    });

    test('buy: diamond −100, owned at +0', () async {
      final repo = await start(FakeRtdbService(), diamond: 130);
      expect(await repo.buyCharacter('u', 'scout', 100), true);
      final p = await read(repo);
      expect((p.diamond, p.characters['scout']), (30, 0));
    });

    test('buy with 99 diamonds or already owned changes nothing', () async {
      final db = FakeRtdbService();
      final repo = await start(db, diamond: 99);
      final before = await db.get('users/u');
      expect(await repo.buyCharacter('u', 'scout', 100), false);
      expect(await db.get('users/u'), before);

      await db.update('users/u', {'diamond': 500});
      expect(await repo.buyCharacter('u', 'scout', 100), true);
      expect(await repo.buyCharacter('u', 'scout', 100), false);
      expect((await read(repo)).diamond, 400);
    });

    test('equip an owned character', () async {
      final repo = await start(FakeRtdbService(), diamond: 100);
      await repo.buyCharacter('u', 'assault', 100);
      await repo.equipCharacter('u', 'assault');
      expect((await read(repo)).equippedCharacter, 'assault');
    });

    group('upgrade (gold, same as weapons)', () {
      Future<(int, int?)> goldAndLevel(ProfileRepository r) async {
        final p = await read(r);
        return (p.gold, p.characters['basic']);
      }

      test('success: gold − cost, +1', () async {
        final repo = await start(FakeRtdbService(), gold: 5000);
        expect(
          await repo.upgradeCharacter(
            'u',
            'basic',
            fromLevel: 0,
            cost: 2000,
            success: true,
          ),
          true,
        );
        expect(await goldAndLevel(repo), (3000, 1));
      });

      test('fail: gold − cost, level stays', () async {
        final repo = await start(FakeRtdbService(), gold: 5000);
        await repo.upgradeCharacter(
          'u',
          'basic',
          fromLevel: 0,
          cost: 2000,
          success: false,
        );
        expect(await goldAndLevel(repo), (3000, 0));
      });

      test('not enough gold or wrong level: nothing changes', () async {
        final repo = await start(FakeRtdbService(), gold: 1999);
        expect(
          await repo.upgradeCharacter(
            'u',
            'basic',
            fromLevel: 0,
            cost: 2000,
            success: true,
          ),
          false,
        );
        expect(
          await repo.upgradeCharacter(
            'u',
            'basic',
            fromLevel: 3,
            cost: 0,
            success: true,
          ),
          false,
        );
        expect(await goldAndLevel(repo), (1999, 0));
      });

      test('a rerun of the transaction applies once', () async {
        final db = FakeRtdbService()..rerunTransactions = true;
        final repo = await start(db, gold: 5000);
        await repo.upgradeCharacter(
          'u',
          'basic',
          fromLevel: 0,
          cost: 2000,
          success: true,
        );
        expect(await goldAndLevel(repo), (3000, 1));
      });
    });
  });
}
