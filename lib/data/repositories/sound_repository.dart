import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../rules/sound.dart';
import '../services/sound_service.dart';

final soundRepositoryProvider = Provider(
  (ref) => SoundRepository(SoundService()),
);

/// 게임이 효과음을 내는 단일 창구. 소리가 안 나도 게임은 멈추지 않는다.
class SoundRepository {
  SoundRepository(this._sound);

  final SoundService _sound;

  Future<void> load() => _sound.load([
    for (final s in Sfx.values) (file: s.file, voices: s.voices),
  ]);

  /// 기다리지 않고 바로 낸다(게임 루프를 막지 않게).
  void play(Sfx sfx, {double volume = 1}) =>
      unawaited(_sound.play(sfx.file, volume));
}
