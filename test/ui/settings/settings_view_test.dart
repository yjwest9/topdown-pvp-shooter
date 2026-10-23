import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/settings_repository.dart';
import 'package:topsoldier/data/services/auth_service.dart';
import 'package:topsoldier/data/services/prefs_service.dart';
import 'package:topsoldier/ui/settings/settings_view.dart';

import '../../fakes.dart';

Future<FakeAuthService> open(
  WidgetTester tester, {
  GoogleLink link = GoogleLink.linked,
}) async {
  final auth = FakeAuthService('anon', linkResult: link);
  tester.view
    ..physicalSize = const Size(740, 360)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  PackageInfo.setMockInitialValues(
    appName: 'TOP SOLDIER',
    packageName: 'com.yjseo.topsoldier',
    version: '0.1.4',
    buildNumber: '5',
    buildSignature: '',
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(AuthRepository(auth)),
      ],
      child: const MaterialApp(home: SettingsView()),
    ),
  );
  await tester.pump();
  await tester.pump();
  return auth;
}

/// 목록 아래쪽(가로 화면에선 화면 밖)에 있는 항목을 눌러 구글 연결을 시작한다.
Future<void> tapLink(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('구글 계정 연결'), 100);
  await tester.ensureVisible(find.text('구글 계정 연결'));
  await tester.pump();
  await tester.tap(find.text('구글 계정 연결'));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('740x360: nothing overflows, sound switch is there and on', (
    tester,
  ) async {
    await open(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('효과음'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, isTrue);
  });

  testWidgets('turning the sound switch off is saved on the device', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('효과음'));
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, isFalse);
    expect(await SettingsRepository(PrefsService()).soundEnabled(), isFalse);
  });

  testWidgets('linking google keeps the account and shows the email', (
    tester,
  ) async {
    final auth = await open(tester);
    await tapLink(tester);
    await tester.pump();
    await tester.pump();
    expect(find.text('me@gmail.com'), findsOneWidget);
    expect(auth.uid, 'anon');
  });

  testWidgets('cancelling the google picker changes nothing', (tester) async {
    final auth = await open(tester, link: GoogleLink.cancelled);
    await tapLink(tester);
    await tester.pump();
    await tester.pump();
    expect(find.text('me@gmail.com'), findsNothing);
    expect(auth.googleEmail, isNull);
  });

  testWidgets('google account already in use: switch only after confirming', (
    tester,
  ) async {
    final auth = await open(tester, link: GoogleLink.exists);
    await tapLink(tester);
    await tester.pump();
    await tester.pump();
    expect(find.text('이미 사용 중인 구글 계정'), findsOneWidget);
    expect(auth.uid, 'anon');

    await tester.tap(find.text('취소'));
    await tester.pump();
    await tester.pump();
    expect(auth.uid, 'anon');

    await tapLink(tester);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('바꾸기'));
    await tester.pump();
    await tester.pump();
    expect(auth.uid, 'google-uid');
  });
}
