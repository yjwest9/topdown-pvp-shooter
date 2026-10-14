import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/repositories/ad_repository.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/profile_repository.dart';
import 'package:topsoldier/data/repositories/room_repository.dart';
import 'package:topsoldier/ui/shop/shop_view_model.dart';

import '../../fakes.dart';

Future<ProviderContainer> shop(
  FakeRtdbService db,
  FakeAdService ads, {
  int gold = 0,
  int? lastAdAt,
}) async {
  final repo = ProfileRepository(db);
  await repo.create('u', 'A');
  await db.update('users/u', {'gold': gold, 'lastAdAt': ?lastAdAt});
  final c = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        AuthRepository(FakeAuthService('u')),
      ),
      profileRepositoryProvider.overrideWithValue(repo),
      roomRepositoryProvider.overrideWithValue(RoomRepository(db)),
      adRepositoryProvider.overrideWithValue(AdRepository(ads)),
    ],
  );
  addTearDown(c.dispose);
  c.listen(shopProvider, (_, _) {});
  await pumpEventQueue();
  return c;
}

void main() {
  int now() => DateTime.now().millisecondsSinceEpoch;

  test('watched to the end → +10,000G and the cooldown starts', () async {
    final db = FakeRtdbService()..serverTime = now();
    final c = await shop(db, FakeAdService(), gold: 500);
    expect(c.read(shopProvider).ad, AdStatus.ready);

    expect(await c.read(shopProvider.notifier).watchAd(), true);
    await pumpEventQueue();
    final s = c.read(shopProvider);
    expect(s.profile.gold, 10500);
    expect(s.cooldownLeft(now()), greaterThan(const Duration(minutes: 59)));
  });

  test('closed before the end → no gold, no cooldown', () async {
    final db = FakeRtdbService()..serverTime = now();
    final c = await shop(db, FakeAdService(earn: false), gold: 500);

    expect(await c.read(shopProvider.notifier).watchAd(), false);
    await pumpEventQueue();
    final s = c.read(shopProvider);
    expect((s.profile.gold, s.profile.lastAdAt), (500, null));
  });

  test('during the cooldown the ad is not shown', () async {
    final ads = FakeAdService();
    final c = await shop(FakeRtdbService(), ads, lastAdAt: now() - 60000);

    expect(await c.read(shopProvider.notifier).watchAd(), false);
    expect(ads.shown, 0);
  });

  test('load failure → failed, retry → ready', () async {
    final ads = FakeAdService(loads: false);
    final c = await shop(FakeRtdbService(), ads);
    expect(c.read(shopProvider).ad, AdStatus.failed);

    ads.loads = true;
    await c.read(shopProvider.notifier).loadAd();
    expect(c.read(shopProvider).ad, AdStatus.ready);
  });

  test('exchange: 100,000G → 0G, +100 diamond; then no more', () async {
    final c = await shop(FakeRtdbService(), FakeAdService(), gold: 100000);
    final vm = c.read(shopProvider.notifier);

    expect(await vm.exchange(), true);
    await pumpEventQueue();
    final p = c.read(shopProvider).profile;
    expect((p.gold, p.diamond), (0, 100));
    expect(c.read(shopProvider).canExchange, false);
    expect(await vm.exchange(), false);
  });
}
