import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/repositories/ad_repository.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/profile_repository.dart';
import 'package:topsoldier/data/repositories/room_repository.dart';
import 'package:topsoldier/ui/shop/shop_view.dart';

import '../../fakes.dart';

Future<void> pumpShop(
  WidgetTester tester, {
  required FakeAdService ads,
  int gold = 0,
  int diamond = 0,
  int? lastAdAt,
}) async {
  tester.view
    ..physicalSize = const Size(740, 360)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = FakeRtdbService();
  await ProfileRepository(db).create('u', 'A');
  await db.update('users/u', {
    'gold': gold,
    'diamond': diamond,
    'lastAdAt': ?lastAdAt,
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          AuthRepository(FakeAuthService('u')),
        ),
        profileRepositoryProvider.overrideWithValue(ProfileRepository(db)),
        roomRepositoryProvider.overrideWithValue(RoomRepository(db)),
        adRepositoryProvider.overrideWithValue(AdRepository(ads)),
      ],
      child: const MaterialApp(home: ShopView()),
    ),
  );
  await tester.pump();
}

FilledButton button(WidgetTester tester, String text) => tester.widget(
  find.ancestor(of: find.text(text), matching: find.byType(FilledButton)),
);

void main() {
  testWidgets('740×360 with big numbers fits; ad ready, exchange enabled', (
    tester,
  ) async {
    await pumpShop(
      tester,
      ads: FakeAdService(),
      gold: 123456789,
      diamond: 99999,
    );
    expect(find.text('123,456,789'), findsOneWidget);
    expect(button(tester, '광고 보고 10,000G').onPressed, isNotNull);
    expect(button(tester, '100 다이아 받기 — 100,000G').onPressed, isNotNull);
    expect(find.text('준비 중'), findsNWidgets(3));
  });

  testWidgets('cooldown → ad button disabled with the time left', (
    tester,
  ) async {
    final last = DateTime.now().millisecondsSinceEpoch - 48000;
    await pumpShop(tester, ads: FakeAdService(), gold: 99999, lastAdAt: last);
    final b = find.textContaining('다시 받기까지 59:');
    expect(b, findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(of: b, matching: find.byType(FilledButton)),
          )
          .onPressed,
      isNull,
    );
    // 골드가 모자라면 환전도 못 누른다.
    expect(button(tester, '100 다이아 받기 — 100,000G').onPressed, isNull);
  });

  testWidgets('web (no ad support) → "앱에서만 가능"', (tester) async {
    await pumpShop(tester, ads: FakeAdService(supported: false));
    expect(button(tester, '앱에서만 가능').onPressed, isNull);
  });

  testWidgets('load failed → message and retry', (tester) async {
    final ads = FakeAdService(loads: false);
    await pumpShop(tester, ads: ads);
    expect(find.text('광고를 불러오지 못했습니다'), findsOneWidget);

    ads.loads = true;
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(find.text('광고 보고 10,000G'), findsOneWidget);
  });

  testWidgets('watch to the end → "+10,000 G" and the gold updates', (
    tester,
  ) async {
    await pumpShop(tester, ads: FakeAdService(), gold: 5);
    await tester.tap(find.text('광고 보고 10,000G'));
    await tester.pump();
    expect(find.text('+10,000 G'), findsOneWidget);
    expect(find.text('10,005'), findsOneWidget);
  });
}
