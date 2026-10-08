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
}
