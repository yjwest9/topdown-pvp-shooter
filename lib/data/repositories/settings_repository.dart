import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/prefs_service.dart';

final settingsRepositoryProvider = Provider(
  (ref) => SettingsRepository(PrefsService()),
);

/// 기기에 저장하는 사용자 설정.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final PrefsService _prefs;

  static const _minimapRotatesKey = 'minimap_rotates';

  /// 미니맵이 내 방향으로 도는지(발로란트식). false면 내 진영이 늘 아래인 고정.
  /// 처음엔 도는 쪽.
  Future<bool> minimapRotates() async =>
      await _prefs.getBool(_minimapRotatesKey) ?? true;

  Future<void> setMinimapRotates(bool value) =>
      _prefs.setBool(_minimapRotatesKey, value);
}
