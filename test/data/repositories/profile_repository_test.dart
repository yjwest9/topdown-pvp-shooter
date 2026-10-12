import 'package:flutter_test/flutter_test.dart';
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
}
