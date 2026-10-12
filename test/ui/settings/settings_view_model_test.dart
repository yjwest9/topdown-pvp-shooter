import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/ui/settings/settings_view_model.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults: sensitivity 5, minimap rotates, both slots AUTO', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final s = await c.read(settingsProvider.future);
    expect((s.sensitivity, s.minimapRotates), (defaultSensitivity, true));
    expect(
      (s.primaryFireMode, s.secondaryFireMode),
      (FireMode.auto, FireMode.auto),
    );
  });

  test('sensitivity keeps one decimal place', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(settingsProvider.future);
    await c.read(settingsProvider.notifier).setSensitivity(5.6999);
    expect(c.read(settingsProvider).value!.sensitivity, closeTo(5.7, 1e-9));
    await c.read(settingsProvider.notifier).setSensitivity(3.74);
    expect(c.read(settingsProvider).value!.sensitivity, closeTo(3.7, 1e-9));
  });

  test('changes are saved and come back after an app restart', () async {
    final c = ProviderContainer();
    await c.read(settingsProvider.future);
    final vm = c.read(settingsProvider.notifier);
    await vm.setSensitivity(5.7);
    await vm.setMinimapRotates(false);
    await vm.setFireMode(FireMode.manual, primary: true);
    c.dispose();

    final again = ProviderContainer();
    addTearDown(again.dispose);
    final s = await again.read(settingsProvider.future);
    expect(s.sensitivity, closeTo(5.7, 1e-9));
    expect(s.minimapRotates, false);
    expect(
      (s.primaryFireMode, s.secondaryFireMode),
      (FireMode.manual, FireMode.auto),
    );
  });
}
