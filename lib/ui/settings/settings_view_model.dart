import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repository.dart';
import '../../rules/balance.dart';

class SettingsState {
  const SettingsState({
    this.sensitivity = defaultSensitivity,
    this.minimapRotates = true,
    this.soundEnabled = true,
    this.primaryFireMode = FireMode.auto,
    this.secondaryFireMode = FireMode.auto,
  });

  /// 시점 감도 1~10.
  final double sensitivity;
  final bool minimapRotates;

  /// 효과음 켜기/끄기(볼륨 조절은 없음).
  final bool soundEnabled;

  /// 주무기·보조무기 칸의 발사 방식(무기를 바꿔도 칸 설정을 따른다).
  final FireMode primaryFireMode;
  final FireMode secondaryFireMode;

  SettingsState copyWith({
    double? sensitivity,
    bool? minimapRotates,
    bool? soundEnabled,
    FireMode? primaryFireMode,
    FireMode? secondaryFireMode,
  }) => SettingsState(
    sensitivity: sensitivity ?? this.sensitivity,
    minimapRotates: minimapRotates ?? this.minimapRotates,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    primaryFireMode: primaryFireMode ?? this.primaryFireMode,
    secondaryFireMode: secondaryFireMode ?? this.secondaryFireMode,
  );
}

/// 기기에 저장하는 설정. 앱 시작 때 한 번 읽고, 바꾸면 바로 저장한다.
final settingsProvider =
    AsyncNotifierProvider<SettingsViewModel, SettingsState>(
      SettingsViewModel.new,
    );

class SettingsViewModel extends AsyncNotifier<SettingsState> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  Future<SettingsState> build() async {
    FireMode mode(bool? auto) => auto ?? true ? FireMode.auto : FireMode.manual;
    return SettingsState(
      sensitivity: (await _repo.sensitivity() ?? defaultSensitivity).clamp(
        minSensitivity,
        maxSensitivity,
      ),
      minimapRotates: await _repo.minimapRotates(),
      soundEnabled: await _repo.soundEnabled(),
      primaryFireMode: mode(await _repo.fireAuto(primary: true)),
      secondaryFireMode: mode(await _repo.fireAuto(primary: false)),
    );
  }

  SettingsState get _now => state.value ?? const SettingsState();

  /// 소수 한 자리로 맞춰 저장한다.
  Future<void> setSensitivity(double value) async {
    final v = (value / sensitivityStep).round() * sensitivityStep;
    state = AsyncData(_now.copyWith(sensitivity: v));
    await _repo.setSensitivity(v);
  }

  Future<void> setMinimapRotates(bool value) async {
    state = AsyncData(_now.copyWith(minimapRotates: value));
    await _repo.setMinimapRotates(value);
  }

  Future<void> setSoundEnabled(bool value) async {
    state = AsyncData(_now.copyWith(soundEnabled: value));
    await _repo.setSoundEnabled(value);
  }

  Future<void> setFireMode(FireMode mode, {required bool primary}) async {
    state = AsyncData(
      primary
          ? _now.copyWith(primaryFireMode: mode)
          : _now.copyWith(secondaryFireMode: mode),
    );
    await _repo.setFireAuto(primary: primary, auto: mode == FireMode.auto);
  }
}
