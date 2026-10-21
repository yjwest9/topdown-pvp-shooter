import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/profile_repository.dart';
import 'package:topsoldier/ui/loadout/loadout_view.dart';
import 'package:topsoldier/ui/settings/settings_view.dart';

import '../../fakes.dart';

/// 작은 가로 폰(740×360)에 [page]를 띄운다. 골드 [gold], 기본 무기 보유.
Future<void> open(
  WidgetTester tester,
  Widget page, {
  int gold = 0,
  Future<void> Function(FakeRtdbService db, String k2Id)? seed,
}) async {
  tester.view
    ..physicalSize = const Size(740, 360)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  PackageInfo.setMockInitialValues(
    appName: 'TOP SOLDIER',
    packageName: 'com.yjseo.topsoldier',
    version: '0.1.1',
    buildNumber: '2',
    buildSignature: '',
  );
  final db = FakeRtdbService();
  final repo = ProfileRepository(db);
  await repo.create('u', 'A');
  await db.update('users/u', {'gold': gold});
  await repo.grantStarter('u', primary: 'rifle_standard', secondary: 'pistol');
  if (seed != null) {
    final p = (await repo.watch('u').first)!;
    await seed(db, p.owned('rifle_standard')!.id);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          AuthRepository(FakeAuthService('u')),
        ),
        profileRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(home: page),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('owned weapon: equip, no buy button. not owned: price or '
      '"골드 부족"', (tester) async {
    await open(tester, const LoadoutView(), gold: 5000);

    expect(find.text('K2'), findsWidgets);
    expect(find.text('장착 중'), findsOneWidget); // K2는 장착 중
    expect(find.textContaining('구매'), findsNothing);

    await tester.tap(find.text('FAMAS'));
    await tester.pump();
    expect(find.text('골드 부족 (20,000 G)'), findsOneWidget);

    await tester.tap(find.text('저격'));
    await tester.pump();
    expect(find.text('TRG-42'), findsWidgets);
  });

  testWidgets('owned weapon shows the upgrade panel; low gold blocks it', (
    tester,
  ) async {
    await open(tester, const LoadoutView(), gold: 1000);
    expect(find.text('강화 +0 → +1'), findsOneWidget);
    expect(find.text('2,000 G · 성공률 90%'), findsOneWidget);
    expect(find.text('데미지 13.0 → 13.3'), findsOneWidget);
    expect(find.text('골드 부족'), findsOneWidget);
    // 미보유 무기에는 강화 영역이 없다
    await tester.tap(find.text('FAMAS'));
    await tester.pump();
    expect(find.textContaining('강화 +'), findsNothing);
  });

  testWidgets('enough gold → buy button', (tester) async {
    await open(tester, const LoadoutView(), gold: 20000);
    await tester.tap(find.text('M14'));
    await tester.pump();
    expect(find.text('구매 20,000 G'), findsOneWidget);
  });

  testWidgets('settings: primary/secondary fire mode and the app version', (
    tester,
  ) async {
    await open(tester, const SettingsView());
    expect(find.text('주무기 발사'), findsOneWidget);
    expect(find.text('보조무기 발사'), findsOneWidget);
    expect(find.text('AUTO'), findsNWidgets(2));
    expect(find.text('5.0'), findsOneWidget); // 감도 소수 한 자리
    await tester.scrollUntilVisible(find.text('앱 버전'), 100);
    expect(find.text('0.1.1+2'), findsOneWidget);
  });

  /// K2(장착)를 E+5로, FAMAS(E+5, 장착 안 함)를 더한다.
  Future<void> twoE5(FakeRtdbService db, String k2Id) async {
    await db.update('users/u/weapons/$k2Id', {'level': 5});
    await db.update('users/u/weapons/m1', {
      'weaponId': 'rifle_rapid',
      'grade': 'E',
      'level': 5,
      'acquiredAt': 1,
    });
  }

  testWidgets('E+5 weapon with a same-family E+5: merge area → pick → confirm '
      '→ D+0, material gone, gold −15,000', (tester) async {
    await open(tester, const LoadoutView(), gold: 20000, seed: twoE5);
    expect(find.text('합성'), findsOneWidget);
    expect(find.text('FAMAS +5'), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, 'FAMAS +5'));
    await tester.pumpAndSettle();
    expect(find.textContaining('D+0이 되고 재료는 사라집니다'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '합성'));
    await tester.pumpAndSettle();

    // 목록(배지 없음)은 "D+0", 상세(D 배지 옆)는 "+0"만.
    expect(find.text('K2 D+0'), findsOneWidget);
    expect(find.text('K2 +0'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    expect(find.text('FAMAS +5'), findsNothing); // 재료는 사라졌다
    expect(find.text('5,000'), findsOneWidget); // 골드
    expect(find.text('합성'), findsNothing);
  });

  testWidgets('equipped material is disabled', (tester) async {
    await open(tester, const LoadoutView(), gold: 20000, seed: twoE5);
    // FAMAS를 기준으로 → 장착 중인 K2가 재료 후보인데 비활성.
    await tester.tap(find.text('FAMAS +5').first);
    await tester.pump();
    final k2 = find.widgetWithText(OutlinedButton, 'K2 +5 (장착 중)');
    expect(k2, findsOneWidget);
    expect(tester.widget<OutlinedButton>(k2).onPressed, isNull);
  });

  testWidgets('not enough gold → materials disabled with a gold notice', (
    tester,
  ) async {
    await open(tester, const LoadoutView(), gold: 14999, seed: twoE5);
    final b = find.widgetWithText(OutlinedButton, 'FAMAS +5');
    expect(tester.widget<OutlinedButton>(b).onPressed, isNull);
    expect(find.textContaining('골드 부족'), findsWidgets);
  });

  testWidgets('no merge area for an E+0 weapon', (tester) async {
    await open(tester, const LoadoutView(), gold: 20000);
    expect(find.text('합성'), findsNothing);
  });
}
