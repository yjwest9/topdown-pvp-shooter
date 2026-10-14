import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/profile_repository.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/upgrade.dart';
import 'package:topsoldier/ui/character/character_view_model.dart';
import 'package:topsoldier/ui/loadout/loadout_view_model.dart';

import '../../fakes.dart';

Future<ProviderContainer> characterScreen(
  FakeRtdbService db, {
  int gold = 0,
  int diamond = 0,
  double roll = 0.5,
}) async {
  final repo = ProfileRepository(db);
  await repo.create('u', 'A');
  await db.update('users/u', {'gold': gold, 'diamond': diamond});
  await repo.grantStarterCharacter('u', id: 'basic');
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
  c.listen(characterProvider, (_, _) {});
  await pumpEventQueue();
  return c;
}

void main() {
  test('opens on the equipped basic soldier; only basic is owned', () async {
    final c = await characterScreen(FakeRtdbService());
    final s = c.read(characterProvider);
    expect(s.selected, basicSoldier);
    expect(
      [for (final x in characters) s.owns(x)],
      [true, false, false, false],
    );
    expect(s.isEquipped(basicSoldier), true);
  });

  test('buy scout with 100 diamonds, then equip it', () async {
    final c = await characterScreen(FakeRtdbService(), diamond: 100);
    final vm = c.read(characterProvider.notifier)..select(scout);
    expect(c.read(characterProvider).canAfford, true);

    expect(await vm.buy(), true);
    await pumpEventQueue();
    expect(c.read(characterProvider).profile.diamond, 0);
    expect(c.read(characterProvider).owns(scout), true);

    await vm.equip();
    await pumpEventQueue();
    expect(c.read(characterProvider).isEquipped(scout), true);
  });

  test('99 diamonds: cannot buy, nothing changes', () async {
    final db = FakeRtdbService();
    final c = await characterScreen(db, diamond: 99);
    final vm = c.read(characterProvider.notifier)..select(assault);
    expect(c.read(characterProvider).canAfford, false);
    expect(await vm.buy(), false);
    await pumpEventQueue();
    expect(c.read(characterProvider).profile.diamond, 99);
  });

  test('upgrade the basic soldier with gold: success then fail', () async {
    final db = FakeRtdbService();
    final c = await characterScreen(db, gold: 10000, roll: 0.1);
    final vm = c.read(characterProvider.notifier);
    expect(await vm.upgrade(), UpgradeOutcome.success);
    await pumpEventQueue();
    var s = c.read(characterProvider);
    expect((s.levelOf(basicSoldier), s.profile.gold), (1, 8000));
    expect(s.upgradeSeq, 1);

    final failing = await characterScreen(db, gold: 10000, roll: 0.99);
    expect(
      await failing.read(characterProvider.notifier).upgrade(),
      UpgradeOutcome.fail,
    );
    await pumpEventQueue();
    s = failing.read(characterProvider);
    expect(s.levelOf(basicSoldier), 0); // 새 프로필로 다시 만든 쪽
  });

  test('not enough gold: nothing saved', () async {
    final c = await characterScreen(FakeRtdbService(), gold: 1999, roll: 0);
    expect(
      await c.read(characterProvider.notifier).upgrade(),
      UpgradeOutcome.notEnoughGold,
    );
    await pumpEventQueue();
    expect(c.read(characterProvider).profile.gold, 1999);
  });
}
