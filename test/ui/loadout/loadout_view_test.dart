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
Future<void> open(WidgetTester tester, Widget page, {int gold = 0}) async {
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
}
