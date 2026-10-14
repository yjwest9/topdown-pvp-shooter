import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

/// 효과음 재생(decisions 17장). 파일마다 [AudioPool]을 두어 연사해도 소리가 끊기거나
/// 쌓이지 않는다. 소리를 못 내는 곳(테스트, 웹에서 첫 터치 전)에서는 조용히 넘어간다.
class SoundService {
  final _pools = <String, AudioPool>{};

  /// [voices]개의 재생기를 미리 만들어 둔다. 이미 만든 파일은 건너뛴다.
  Future<void> load(Iterable<({String file, int voices})> files) async {
    for (final f in files) {
      if (_pools.containsKey(f.file)) continue;
      try {
        _pools[f.file] = await FlameAudio.createPool(
          f.file,
          maxPlayers: f.voices,
        );
      } catch (e) {
        debugPrint('sound load failed (${f.file}): $e');
      }
    }
  }

  /// 아직 안 불러왔거나 재생이 막히면(브라우저가 첫 터치 전엔 막음) 아무 일도 안 한다.
  Future<void> play(String file, double volume) async {
    try {
      await _pools[file]?.start(volume: volume);
    } catch (_) {}
  }
}
