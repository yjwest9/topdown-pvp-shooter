import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:topsoldier/data/repositories/settings_repository.dart';
import 'package:topsoldier/data/services/prefs_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('minimap rotates by default', () async {
    final repo = SettingsRepository(PrefsService());
    expect(await repo.minimapRotates(), isTrue);
  });

  test('saved choice survives a new repository (app restart)', () async {
    await SettingsRepository(PrefsService()).setMinimapRotates(false);
    expect(await SettingsRepository(PrefsService()).minimapRotates(), isFalse);
  });

  test('sensitivity and primary/secondary fire mode are saved', () async {
    final repo = SettingsRepository(PrefsService());
    expect(await repo.sensitivity(), isNull);
    expect(await repo.fireAuto(primary: true), isNull);

    await repo.setSensitivity(5.7);
    await repo.setFireAuto(primary: true, auto: false);

    final again = SettingsRepository(PrefsService());
    expect(await again.sensitivity(), 5.7);
    expect(await again.fireAuto(primary: true), false);
    expect(await again.fireAuto(primary: false), isNull);
  });

  test('sound is on by default and the choice is saved', () async {
    expect(await SettingsRepository(PrefsService()).soundEnabled(), isTrue);

    await SettingsRepository(PrefsService()).setSoundEnabled(false);
    expect(await SettingsRepository(PrefsService()).soundEnabled(), isFalse);
  });
}
