import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:topsoldier/data/repositories/settings_repository.dart';
import 'package:topsoldier/data/services/prefs_service.dart';
import 'package:topsoldier/ui/settings/settings_view.dart';

Future<void> open(WidgetTester tester) async {
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
    const ProviderScope(child: MaterialApp(home: SettingsView())),
  );
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
}
