import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_info_service.dart';
import '../services/prefs_service.dart';

final settingsRepositoryProvider = Provider(
  (ref) => SettingsRepository(PrefsService()),
);

/// 설정 화면에 보이는 앱 버전.
final appVersionProvider = FutureProvider((ref) => AppInfoService().version());

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

  static const _soundEnabledKey = 'sound_enabled';

  /// 효과음 켜기/끄기. 처음엔 켜짐(decisions 17장).
  Future<bool> soundEnabled() async =>
      await _prefs.getBool(_soundEnabledKey) ?? true;

  Future<void> setSoundEnabled(bool value) =>
      _prefs.setBool(_soundEnabledKey, value);

  static const _sensitivityKey = 'sensitivity';

  /// 시점 감도. 저장한 적 없으면 null(기본값은 규칙이 정한다).
  Future<double?> sensitivity() => _prefs.getDouble(_sensitivityKey);

  Future<void> setSensitivity(double value) =>
      _prefs.setDouble(_sensitivityKey, value);

  /// 주무기·보조무기 칸의 발사 방식: true 자동, false 수동. 저장한 적 없으면 null.
  Future<bool?> fireAuto({required bool primary}) =>
      _prefs.getBool(primary ? 'fire_auto_primary' : 'fire_auto_secondary');

  Future<void> setFireAuto({required bool primary, required bool auto}) =>
      _prefs.setBool(
        primary ? 'fire_auto_primary' : 'fire_auto_secondary',
        auto,
      );
}
