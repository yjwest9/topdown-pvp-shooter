import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/profile_repository.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/ui/loadout/loadout_view_model.dart';

import '../../fakes.dart';

Future<ProviderContainer> loadout(FakeRtdbService db, {int gold = 0}) async {
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

  test('no profile yet → default K2 / M9', () {
    final e = equippedWeapons(null);
    expect((e.primary, e.secondary), (startingPrimary, startingSecondary));
  });
}
