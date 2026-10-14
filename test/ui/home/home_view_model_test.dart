import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/models/holiday.dart';
import 'package:topsoldier/data/repositories/ad_repository.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/profile_repository.dart';
import 'package:topsoldier/ui/home/home_view_model.dart';

import '../../fakes.dart';

ProviderContainer home(
  FakeRtdbService db, {
  Holiday? holiday,
  FakeAdService? ads,
}) {
  final c = ProviderContainer(
    overrides: [
      adRepositoryProvider.overrideWithValue(
        AdRepository(ads ?? FakeAdService()),
      ),
      authRepositoryProvider.overrideWithValue(
        AuthRepository(FakeAuthService('u')),
      ),
      profileRepositoryProvider.overrideWithValue(ProfileRepository(db)),
      holidayProvider.overrideWith((ref) => holiday),
    ],
  );
  addTearDown(c.dispose);
  c.listen(homeProvider, (_, _) {});
  return c;
}

void main() {
  test('opening home preloads one ad, not again when the profile changes '
      '(상점에서 바로 누를 수 있게)', () async {
    final db = FakeRtdbService();
    final ads = FakeAdService();
    final c = home(db, ads: ads);
    await pumpEventQueue();
    await c.read(homeProvider.notifier).saveNickname('탑솔져');
    await pumpEventQueue();
    expect(c.read(homeProvider).profile.nickname, '탑솔져');
    expect(ads.loadCalls, 1);
  });

  test(
    'first run: no profile → nickname form, then the profile shows',
    () async {
      final db = FakeRtdbService();
      final c = home(db);
      await pumpEventQueue();
      expect(c.read(homeProvider).needsNickname, true);

      final vm = c.read(homeProvider.notifier);
      expect(vm.defaultNickname, startsWith('Soldier'));
      expect(await vm.saveNickname('x'), isNotNull); // 너무 짧음
      expect(await vm.saveNickname('  탑솔져  '), isNull);
      await pumpEventQueue();

      final s = c.read(homeProvider);
      expect(s.needsNickname, false);
      expect((s.profile.nickname, s.profile.level), ('탑솔져', 1));
    },
  );

  test('shows level, gold and exp bar of the saved profile', () async {
    final db = FakeRtdbService();
    await ProfileRepository(db).create('u', 'A');
    await db.update('users/u', {'level': 3, 'exp': 100, 'gold': 12000});
    final c = home(db);
    await pumpEventQueue();

    final s = c.read(homeProvider);
    expect((s.profile.level, s.profile.gold), (3, 12000));
    expect(s.expRatio, 0.5); // 3레벨은 200 필요
  });

  test('rename keeps the profile', () async {
    final db = FakeRtdbService();
    await ProfileRepository(db).create('u', 'A');
    final c = home(db);
    await pumpEventQueue();
    expect(await c.read(homeProvider.notifier).saveNickname('B2'), isNull);
    await pumpEventQueue();
    expect(c.read(homeProvider).profile.nickname, 'B2');
  });

  test(
    'existing user without weapons gets K2 + M9 equipped, only once',
    () async {
      final db = FakeRtdbService();
      await ProfileRepository(db).create('u', 'A'); // 무기 기능 전에 만든 프로필
      final c = home(db);
      await pumpEventQueue();
      await pumpEventQueue();

      final p = c.read(homeProvider).profile;
      expect(p.hasLoadout, true);
      expect(
        p.weapons.map((w) => w.weaponId),
        unorderedEquals(['rifle_standard', 'pistol']),
      );
      expect(((await db.get('users/u/weapons'))! as Map).length, 2);
    },
  );

  test('existing user gets the basic soldier +0, equipped', () async {
    final db = FakeRtdbService();
    await ProfileRepository(db).create('u', 'A'); // 캐릭터 기능 전에 만든 프로필
    final c = home(db);
    await pumpEventQueue();
    await pumpEventQueue();
    expect(await db.get('users/u/characters'), {
      'basic': {'level': 0},
    });
    expect(await db.get('users/u/equippedCharacter'), 'basic');
    expect(c.read(homeProvider).profile.characters, {'basic': 0});
  });

  test('profile card: win rate and K/D, also with 0 matches', () async {
    final db = FakeRtdbService();
    await ProfileRepository(db).create('u', 'A');
    final c = home(db);
    await pumpEventQueue();
    expect(
      c.read(homeProvider).record,
      containsAll([('승률', '0%'), ('K/D', '0.00')]),
    );

    await db.update('users/u/stats', {
      'matches': 4,
      'wins': 3,
      'kills': 9,
      'deaths': 6,
    });
    await pumpEventQueue();
    expect(
      c.read(homeProvider).record,
      containsAll([
        ('총 판수', '4'),
        ('승 / 패', '3 / 1'),
        ('승률', '75%'),
        ('K/D', '1.50'),
      ]),
    );
  });

  test('event banner only on a holiday', () async {
    final none = home(FakeRtdbService());
    final day = home(
      FakeRtdbService(),
      holiday: Holiday(date: DateTime(2026, 10, 9), name: '한글날'),
    );
    await pumpEventQueue();
    expect(none.read(homeProvider).showEventBanner, false);
    expect(day.read(homeProvider).showEventBanner, true);
  });
}
