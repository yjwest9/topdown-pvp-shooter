import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/profile_repository.dart';
import 'package:topsoldier/data/repositories/room_repository.dart';
import 'package:topsoldier/game/net/match_sync.dart';
import 'package:topsoldier/game/soldier_game.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/rewards.dart';
import 'package:topsoldier/ui/match/match_view.dart';
import 'package:topsoldier/ui/settings/settings_view_model.dart';

import '../../fakes.dart';

Future<FakeRtdbService> openMatch(
  WidgetTester tester,
  MatchMode mode, {
  int endsAt = 0,
}) async {
  SharedPreferences.setMockInitialValues({});
  final db = FakeRtdbService();
  await ProfileRepository(db).create('u', 'A');
  if (endsAt != 0) {
    // 이미 시작한 방(방 meta에 끝나는 시각이 있다).
    await db.set('rooms/1234/meta', {
      'hostUid': 'u',
      'status': 'playing',
      'endsAt': endsAt,
    });
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          AuthRepository(FakeAuthService('u')),
        ),
        profileRepositoryProvider.overrideWithValue(ProfileRepository(db)),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MatchView(
                  mode: mode,
                  match: MatchSync(
                    rooms: RoomRepository(db),
                    code: '1234',
                    uid: 'u',
                    isHost: true,
                    clock: () => db.serverTime,
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return db;
}

/// 게임 안 설정 버튼 → 나가기.
Future<void> exitViaSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('설정'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('나가기'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('no exit button on screen: exit is inside the settings', (
    tester,
  ) async {
    await openMatch(tester, MatchMode.custom);
    expect(find.text('나가기'), findsNothing);
    await tester.tap(find.byTooltip('설정'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('나가기'), findsOneWidget);
    await tester.tap(find.text('계속하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(MatchView), findsOneWidget);
  });

  testWidgets('in-game settings apply right away (sensitivity, fire mode)', (
    tester,
  ) async {
    await openMatch(tester, MatchMode.custom);
    final game = tester
        .widget<RiverpodAwareGameWidget<SoldierGame>>(
          find.byType(RiverpodAwareGameWidget<SoldierGame>),
        )
        .game!;
    await tester.tap(find.byTooltip('설정'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    tester.widget<Slider>(find.byType(Slider)).onChanged!(8.3);
    await tester.pump();
    expect(game.sensitivity, 8.3);
    await tester.tap(find.text('MANUAL').first); // 주무기
    await tester.pump();
    expect(game.primaryFireMode, FireMode.manual);
    expect(game.secondaryFireMode, FireMode.auto);
  });

  testWidgets('in-game sound switch turns the game sound off right away', (
    tester,
  ) async {
    await openMatch(tester, MatchMode.custom);
    final game = tester
        .widget<RiverpodAwareGameWidget<SoldierGame>>(
          find.byType(RiverpodAwareGameWidget<SoldierGame>),
        )
        .game!;
    expect(game.soundEnabled, isTrue);
    await tester.tap(find.byTooltip('설정'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('효과음'));
    await tester.pump();
    expect(game.soundEnabled, isFalse);
    await tester.tap(find.text('효과음'));
    await tester.pump();
    expect(game.soundEnabled, isTrue);
  });

  testWidgets('quick match: leaving asks first, then records a loss with '
      'no reward', (tester) async {
    final db = await openMatch(tester, MatchMode.pvp);

    await exitViaSettings(tester);
    expect(find.text('지금 나가면 패배로 기록됩니다.'), findsOneWidget);
    await tester.tap(find.text('계속하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(MatchView), findsOneWidget); // 안 나감

    await exitViaSettings(tester);
    await tester.tap(find.text('나가기').last); // 확인 창의 버튼
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MatchView), findsNothing);
    final stats = (await db.get('users/u/stats'))! as Map;
    expect((stats['matches'], stats['wins']), (1, 0));
    expect(await db.get('users/u/gold'), 0);
  });

  testWidgets('quick match start writes users/uid/activeMatch (matchId = '
      'room-endsAt, server time)', (tester) async {
    final db = await openMatch(tester, MatchMode.pvp, endsAt: 99000);
    final a = (await db.get('users/u/activeMatch'))! as Map;
    expect(a['matchId'], '1234-99000');
    expect(a['startedAt'], db.serverTime);
  });

  for (final mode in [MatchMode.bot, MatchMode.custom]) {
    testWidgets('$mode never writes activeMatch', (tester) async {
      final db = await openMatch(tester, mode, endsAt: 99000);
      expect(await db.get('users/u/activeMatch'), isNull);
    });
  }

  testWidgets('quick match: leaving (= loss) clears activeMatch in the same '
      'save', (tester) async {
    final db = await openMatch(tester, MatchMode.pvp, endsAt: 99000);
    expect(await db.get('users/u/activeMatch'), isNotNull);

    await exitViaSettings(tester);
    await tester.tap(find.text('나가기').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(await db.get('users/u/activeMatch'), isNull);
    expect(await db.get('users/u/lastMatchId'), '1234-99000');
    expect(((await db.get('users/u/stats'))! as Map)['matches'], 1);
  });

  testWidgets('custom room: leaving is immediate and nothing is recorded', (
    tester,
  ) async {
    final db = await openMatch(tester, MatchMode.custom);
    await exitViaSettings(tester);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MatchView), findsNothing);
    expect(await db.get('users/u/stats/matches'), 0);
  });

  testWidgets('a match starts with the loadout weapons and saved settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'sensitivity': 8.0,
      'fire_auto_primary': false,
      'sound_enabled': false,
    });
    final db = FakeRtdbService();
    final repo = ProfileRepository(db);
    await repo.create('u', 'A');
    await db.update('users/u', {'gold': 20000});
    await repo.grantStarter(
      'u',
      primary: 'rifle_standard',
      secondary: 'pistol',
    );
    await repo.buy('u', 'shotgun_pump', 20000);
    final shotgun = (await repo.watch('u').first)!.owned('shotgun_pump')!;
    await repo.equip('u', shotgun.id, primary: true);

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          AuthRepository(FakeAuthService('u')),
        ),
        profileRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    // 홈이 하듯 프로필·설정을 미리 읽어 둔다.
    container
      ..listen(profileProvider, (_, _) {})
      ..listen(settingsProvider, (_, _) {});
    await tester.runAsync(() => container.read(settingsProvider.future));
    await tester.pump();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MatchView()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final game = tester
        .widget<RiverpodAwareGameWidget<SoldierGame>>(
          find.byType(RiverpodAwareGameWidget<SoldierGame>),
        )
        .game!;
    expect(game.sensitivity, 8);
    expect(game.player.primary.weapon, shotgunPump);
    expect(game.player.secondary.weapon, pistol);
    expect(game.primaryFireMode, FireMode.manual);
    expect(game.secondaryFireMode, FireMode.auto);
    expect(game.soundEnabled, isFalse);
  });
}
