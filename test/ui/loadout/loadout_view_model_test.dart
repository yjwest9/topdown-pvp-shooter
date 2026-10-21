import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/profile_repository.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/upgrade.dart';
import 'package:topsoldier/ui/loadout/loadout_view_model.dart';

import '../../fakes.dart';

Future<ProviderContainer> loadout(
  FakeRtdbService db, {
  int gold = 0,
  double roll = 0.5,
}) async {
  final repo = ProfileRepository(db);
  await repo.create('u', 'A');
  await db.update('users/u', {'gold': gold});
  await repo.grantStarter('u', primary: 'rifle_standard', secondary: 'pistol');
  final c = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        AuthRepository(FakeAuthService('u')),
      ),
      profileRepositoryProvider.overrideWithValue(repo),
      upgradeRollProvider.overrideWithValue(() => roll),
    ],
  );
  addTearDown(c.dispose);
  c.listen(loadoutProvider, (_, _) {});
  await pumpEventQueue();
  return c;
}

void main() {
  test('opens on the equipped primary; tabs list one family', () async {
    final c = await loadout(FakeRtdbService());
    var s = c.read(loadoutProvider);
    expect(s.selected, rifleStandard);
    expect(s.isEquipped(rifleStandard) && s.isEquipped(pistol), true);

    c.read(loadoutProvider.notifier).showFamily(WeaponFamily.sniper);
    s = c.read(loadoutProvider);
    expect(s.list, [sniperBolt, sniperSemi, sniperLight]);
    expect(s.selected, sniperBolt);
    expect(s.owns(sniperBolt), false);
  });

  test('buy with enough gold → owned, gold taken; then equip', () async {
    final c = await loadout(FakeRtdbService(), gold: 30000);
    final vm = c.read(loadoutProvider.notifier)..select(shotgunPump);

    expect(await vm.buy(), true);
    await pumpEventQueue();
    var s = c.read(loadoutProvider);
    expect((s.owns(shotgunPump), s.profile.gold), (true, 10000));
    expect(await vm.buy(), false); // 이미 보유 → 다시 못 삼

    await vm.equip();
    await pumpEventQueue();
    s = c.read(loadoutProvider);
    expect(equippedWeapons(s.profile).primary, shotgunPump);
    expect(equippedWeapons(s.profile).secondary, pistol);
  });

  test('not enough gold → cannot buy, nothing changes', () async {
    final db = FakeRtdbService();
    final c = await loadout(db, gold: 19999);
    final vm = c.read(loadoutProvider.notifier)..select(sniperBolt);
    expect(c.read(loadoutProvider).canAfford, false);
    expect(await vm.buy(), false);
    await pumpEventQueue();
    expect(c.read(loadoutProvider).profile.gold, 19999);
    expect(((await db.get('users/u/weapons'))! as Map).length, 2);
  });

  group('upgrade the selected K2', () {
    Future<(ProviderContainer, LoadoutViewModel)> k2(
      FakeRtdbService db, {
      required int gold,
      required double roll,
    }) async {
      final c = await loadout(db, gold: gold, roll: roll);
      return (c, c.read(loadoutProvider.notifier)..select(rifleStandard));
    }

    test('success (roll under 90%): -2,000 G, +1, plays the effect', () async {
      final (c, vm) = await k2(FakeRtdbService(), gold: 5000, roll: 0.1);
      expect(await vm.upgrade(), UpgradeOutcome.success);
      await pumpEventQueue();
      final s = c.read(loadoutProvider);
      expect((s.profile.gold, s.levelOf(rifleStandard)), (3000, 1));
      expect((s.upgradeResult, s.upgradeSeq), (UpgradeOutcome.success, 1));
      // 장착 무기 단계도 +1 → 다음 매치에 반영
      expect(equippedWeapons(s.profile).primaryLevel, 1);
    });

    test('fail (roll 0.95): only gold is gone', () async {
      final (c, vm) = await k2(FakeRtdbService(), gold: 5000, roll: 0.95);
      expect(await vm.upgrade(), UpgradeOutcome.fail);
      await pumpEventQueue();
      final s = c.read(loadoutProvider);
      expect((s.profile.gold, s.levelOf(rifleStandard)), (3000, 0));
      expect(s.upgradeResult, UpgradeOutcome.fail);
    });

    test('not enough gold: nothing is written', () async {
      final (c, vm) = await k2(FakeRtdbService(), gold: 1999, roll: 0.1);
      expect(await vm.upgrade(), UpgradeOutcome.notEnoughGold);
      await pumpEventQueue();
      final s = c.read(loadoutProvider);
      expect(
        (s.profile.gold, s.levelOf(rifleStandard), s.upgradeSeq),
        (1999, 0, 0),
      );
    });

    test('+5 is the max', () async {
      final db = FakeRtdbService();
      final (c, vm) = await k2(db, gold: 99999, roll: 0.1);
      final id = c.read(loadoutProvider).profile.owned('rifle_standard')!.id;
      await db.update('users/u/weapons/$id', {'level': maxUpgradeLevel});
      await pumpEventQueue();
      expect(await vm.upgrade(), UpgradeOutcome.maxLevel);
      expect(c.read(loadoutProvider).profile.gold, 99999);
    });
  });

  group('merge (decisions 7장)', () {
    /// K2(장착)와 FAMAS(E+5), TRG-42(E+5, 다른 계열)를 가진 상태.
    Future<(ProviderContainer, LoadoutViewModel, FakeRtdbService)> setup({
      int gold = 20000,
      int k2Level = 5,
      double roll = 0.1,
    }) async {
      final db = FakeRtdbService();
      final c = await loadout(db, gold: gold, roll: roll);
      final k2 = c.read(loadoutProvider).profile.owned('rifle_standard')!.id;
      await db.update('users/u/weapons/$k2', {'level': k2Level});
      for (final (id, weaponId, level) in [
        ('m1', 'rifle_rapid', 5),
        ('m2', 'sniper_bolt', 5),
      ]) {
        await db.update('users/u/weapons/$id', {
          'weaponId': weaponId,
          'grade': 'E',
          'level': level,
          'acquiredAt': 1,
        });
      }
      await pumpEventQueue();
      return (c, c.read(loadoutProvider.notifier)..select(rifleStandard), db);
    }

    test('only an E+5 weapon can be a base; materials = same family E+5, '
        'equipped ones flagged', () async {
      final (c, _, _) = await setup(k2Level: 4);
      expect(c.read(loadoutProvider).canMerge, false);
      expect(c.read(loadoutProvider).mergeMaterials, isEmpty);

      final (c2, vm2, _) = await setup();
      var s = c2.read(loadoutProvider);
      expect(s.canMerge, true);
      // TRG-42는 다른 계열이라 후보가 아니다.
      expect(
        [for (final m in s.mergeMaterials) (m.weapon, m.equipped)],
        [(rifleRapid, false)],
      );

      // FAMAS를 기준으로 → 장착 중인 K2가 재료 후보(비활성).
      vm2.select(rifleRapid);
      s = c2.read(loadoutProvider);
      expect(
        [for (final m in s.mergeMaterials) (m.weapon, m.equipped)],
        [(rifleStandard, true)],
      );
    });

    test('pistol and not-owned weapons never show a merge', () async {
      final (c, vm, _) = await setup();
      vm.select(pistol);
      expect(c.read(loadoutProvider).canMerge, false);
      vm.select(shotgunPump); // 안 가짐
      expect(c.read(loadoutProvider).canMerge, false);
    });

    test('merge: gold −15,000, base D+0 (same weapon), material gone, '
        'equipped grade follows', () async {
      final (c, vm, _) = await setup();
      expect(await vm.merge('m1'), true);
      await pumpEventQueue();
      final s = c.read(loadoutProvider);
      expect(s.profile.gold, 5000);
      expect(s.gradeOf(rifleStandard), Grade.d);
      expect(s.levelOf(rifleStandard), 0);
      expect(s.owns(rifleRapid), false);
      expect(s.owns(sniperBolt), true);
      expect(s.mergeSeq, 1);
      expect(equippedWeapons(s.profile).primaryGrade, Grade.d);
      expect(equippedWeapons(s.profile).primaryLevel, 0);
      expect(s.canMerge, false); // D+0은 합성 대상이 아니다
    });

    test('equipped material, other family, or too little gold → refused, '
        'nothing written', () async {
      final (c, vm, db) = await setup(gold: 14999);
      expect(await vm.merge('m1'), false); // 골드 부족
      vm.select(rifleRapid);
      expect(await vm.merge(c.read(loadoutProvider).profile.primaryId!), false);
      expect(await vm.merge('m2'), false); // 다른 계열
      await pumpEventQueue();
      final s = c.read(loadoutProvider);
      expect(s.profile.gold, 14999);
      expect(s.mergeSeq, 0);
      expect(await db.get('users/u/weapons/m1/grade'), 'E');
    });

    test('a D weapon keeps upgrading as before (D+0 → D+1)', () async {
      final (c, vm, _) = await setup(gold: 40000);
      await vm.merge('m1');
      await pumpEventQueue();
      expect(await vm.upgrade(), UpgradeOutcome.success);
      await pumpEventQueue();
      final s = c.read(loadoutProvider);
      expect(s.gradeOf(rifleStandard), Grade.d);
      expect(s.levelOf(rifleStandard), 1);
    });
  });

  test('no profile yet → default K2 / M9', () {
    final e = equippedWeapons(null);
    expect((e.primary, e.secondary), (startingPrimary, startingSecondary));
  });
}
