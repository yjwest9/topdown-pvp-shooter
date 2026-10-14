import 'dart:ui';

import 'package:flame/cache.dart';

import '../rules/appearance.dart';
import 'soldier_art.dart';

/// 게임이 쓰는 그림(맵 타일 `assets/images/` + 코드로 그린 병사). 처음에 한 번 불러 두고 그릴 때는 캐시에서 꺼낸다.
class GameArt {
  GameArt(this.images);

  final Images images;

  /// 앉으면 그림(과 앉기 링)이 이 배율로 줄어든다.
  static const crouchScale = 0.85;

  /// 빠진 그림만 불러온다. 이미 다 있으면(두 번째 매치부터, 테스트) 기다릴 것이 없어서
  /// null을 돌려준다 — 호출하는 쪽이 `await`하지 않으면 로딩 순서가 그대로다.
  Future<void>? load() {
    final missing = [
      for (final f in artFiles)
        if (!images.containsKey(f)) f,
    ];
    return missing.isEmpty ? null : images.loadAll(missing);
  }

  Image tile(String name) => images.fromCache(name);

  /// [characterId]·[pose] 병사를 몸 중심이 (0, 0)에 오게 그린다. 오른쪽(+x)을 본다.
  /// 그림은 코드로 그린다(decisions 8장, [SoldierArt]).
  void drawSoldier(Canvas canvas, String characterId, Pose pose) =>
      SoldierArt.draw(canvas, characterId, pose);
}
