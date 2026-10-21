import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/models/match_stats.dart';
import 'package:topsoldier/data/repositories/ad_repository.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/profile_repository.dart';
import 'package:topsoldier/data/repositories/room_repository.dart';
import 'package:topsoldier/rules/match.dart';
import 'package:topsoldier/rules/rewards.dart';
import 'package:topsoldier/ui/home/home_view_model.dart';
import 'package:topsoldier/ui/result/result_view.dart';
import 'package:topsoldier/ui/result/result_view_model.dart';

import '../../fakes.dart';

const stats = MatchStats(matchId: 'm1', result: MatchResult.win, kills: 2);
const doubleText = '광고 보고 보상 2배';

Future<FakeRtdbService> pumpResult(
  WidgetTester tester, {
  required FakeAdService ads,
  MatchMode mode = MatchMode.bot,
}) async {
  tester.view
    ..physicalSize = const Size(740, 360)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = FakeRtdbService();
  await ProfileRepository(db).create('u', 'A');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          AuthRepository(FakeAuthService('u')),
        ),
        profileRepositoryProvider.overrideWithValue(ProfileRepository(db)),
        roomRepositoryProvider.overrideWithValue(RoomRepository(db)),
        adRepositoryProvider.overrideWithValue(AdRepository(ads)),
        holidayProvider.overrideWith((ref) => null),
      ],
      child: MaterialApp(
        home: ResultView(stats: stats, mode: mode),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

Future<int> goldOf(FakeRtdbService db) async =>
    ((await db.get('users/u/gold')) as num).toInt();

void main() {
  final reward = const ResultViewModel(stats, mode: MatchMode.bot).reward.gold;

  testWidgets('watch the ad to the end → match gold paid once more, '
      'button turns into "2배 받음" and cannot be pressed again', (tester) async {
    final ads = FakeAdService();
    final db = await pumpResult(tester, ads: ads);
    expect(await goldOf(db), reward);

    await tester.tap(find.text(doubleText));
    await tester.pumpAndSettle();

    expect(await goldOf(db), reward * 2);
    expect(find.text('2배 받음'), findsOneWidget);
    expect(find.text(doubleText), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('2배 받음'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(ads.shown, 1);
    // 상점 쿨타임은 건드리지 않는다.
    expect(await db.get('users/u/lastAdAt'), isNull);
  });

  testWidgets('ad closed early (no reward callback) → gold unchanged, '
      'button stays', (tester) async {
    final ads = FakeAdService(earn: false);
    final db = await pumpResult(tester, ads: ads);

    await tester.tap(find.text(doubleText));
    await tester.pumpAndSettle();

    expect(await goldOf(db), reward);
    expect(find.text(doubleText), findsOneWidget);
    expect(find.text('2배 받음'), findsNothing);
  });

  testWidgets('no reward (친선전) → no button and no ad is loaded', (
    tester,
  ) async {
    final ads = FakeAdService();
    await pumpResult(tester, ads: ads, mode: MatchMode.custom);
    expect(find.textContaining('2배'), findsNothing);
    expect(ads.loadCalls, 0);
  });

  testWidgets('web (no ad support) → no button', (tester) async {
    await pumpResult(tester, ads: FakeAdService(supported: false));
    expect(find.textContaining('2배'), findsNothing);
  });

  testWidgets('ad fails to load → button hidden', (tester) async {
    await pumpResult(tester, ads: FakeAdService(loads: false));
    expect(find.textContaining('2배'), findsNothing);
  });
}
