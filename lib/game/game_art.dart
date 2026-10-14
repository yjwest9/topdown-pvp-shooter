import 'dart:ui';

import 'package:flame/cache.dart';

import '../rules/appearance.dart';

/// 게임이 쓰는 그림(`assets/images/`). 처음에 한 번 불러 두고 그릴 때는 캐시에서 꺼낸다.
class GameArt {
  GameArt(this.images);

  final Images images;

  /// 병사 그림 크기 배율. 몸(어깨 너비 43px)이 판정 반지름 16px의 원과 비슷해지게.
  static const soldierScale = 0.8;

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

  static final _smooth = Paint()..filterQuality = FilterQuality.medium;

  /// [characterId]·[pose] 그림을 몸 중심이 (0, 0)에 오게 그린다. 오른쪽(+x)을 본다.
  /// 그림 크기는 포즈마다 다르지만(총이 오른쪽으로 길어짐) 몸은 모두 왼쪽 끝에 맞춰져 있어서
  /// 몸 중심은 서 있는 그림 너비의 절반이다.
  void drawSoldier(
    Canvas canvas,
    String characterId,
    Pose pose, {
    double scale = 1,
  }) {
    final img = images.fromCache(characterSprite(characterId, pose));
    final bodyX =
        images.fromCache(characterSprite(characterId, Pose.stand)).width / 2;
    final s = soldierScale * scale;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(
        -bodyX * s,
        -img.height / 2 * s,
        img.width * s,
        img.height * s,
      ),
      _smooth,
    );
  }
}
