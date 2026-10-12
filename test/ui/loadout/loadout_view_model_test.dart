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

  test('no profile yet → default K2 / M9', () {
    final e = equippedWeapons(null);
    expect((e.primary, e.secondary), (startingPrimary, startingSecondary));
  });
}
