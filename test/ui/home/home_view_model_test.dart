import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/models/holiday.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/profile_repository.dart';
import 'package:topsoldier/ui/home/home_view_model.dart';

import '../../fakes.dart';

ProviderContainer home(FakeRtdbService db, {Holiday? holiday}) {
  final c = ProviderContainer(
    overrides: [
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
