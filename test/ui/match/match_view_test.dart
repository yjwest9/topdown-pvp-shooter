import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/profile_repository.dart';
import 'package:topsoldier/data/repositories/room_repository.dart';
import 'package:topsoldier/game/net/match_sync.dart';
import 'package:topsoldier/rules/rewards.dart';
import 'package:topsoldier/ui/match/match_view.dart';

import '../../fakes.dart';

Future<FakeRtdbService> openMatch(WidgetTester tester, MatchMode mode) async {
  SharedPreferences.setMockInitialValues({});
  final db = FakeRtdbService();
  await ProfileRepository(db).create('u', 'A');
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

void main() {
  testWidgets('quick match: leaving asks first, then records a loss with '
      'no reward', (tester) async {
    final db = await openMatch(tester, MatchMode.pvp);

    await tester.tap(find.text('나가기'));
    await tester.pump();
    expect(find.text('지금 나가면 패배로 기록됩니다.'), findsOneWidget);
    await tester.tap(find.text('계속하기'));
    await tester.pump();
    expect(find.byType(MatchView), findsOneWidget); // 안 나감

    await tester.tap(find.text('나가기'));
    await tester.pump();
    await tester.tap(find.text('나가기').last); // 확인 창의 버튼
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MatchView), findsNothing);
    final stats = (await db.get('users/u/stats'))! as Map;
    expect((stats['matches'], stats['wins']), (1, 0));
    expect(await db.get('users/u/gold'), 0);
  });

  testWidgets('custom room: leaving is immediate and nothing is recorded', (
    tester,
  ) async {
    final db = await openMatch(tester, MatchMode.custom);
    await tester.tap(find.text('나가기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MatchView), findsNothing);
    expect(await db.get('users/u/stats/matches'), 0);
  });
}
