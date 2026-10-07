import 'game_map.dart';

export 'game_map.dart' show MapBlock;

/// 하드코딩 훈련소 맵(1400², 표적 4개). PvP는 frontline(Tiled).
class TestMap extends GameMap {
  TestMap() : super(width: mapSize, height: mapSize, blocks: _blocks);

  static const mapSize = 1400.0;
  static const spawn = (x: 700.0, y: 1000.0);

  /// 훈련용 표적: ① 탁 트인 곳 ② 낮은 상자(770~840) 바로 뒤에 앉음
  /// ③ 스폰에서 1080px ④ 낮은 상자(1120~1190, 280~350) 위에 앉음.
  static const dummySpots = [
    (pos: (x: 700.0, y: 700.0), crouching: false, onCrate: false),
    (pos: (x: 805.0, y: 740.0), crouching: true, onCrate: false),
    (pos: (x: 100.0, y: 100.0), crouching: false, onCrate: false),
    (pos: (x: 1155.0, y: 315.0), crouching: true, onCrate: true),
  ];

  static const _blocks = <MapBlock>[
    // 외곽 벽
    MapBlock((left: 0, top: 0, right: 1400, bottom: 20)),
    MapBlock((left: 0, top: 1380, right: 1400, bottom: 1400)),
    MapBlock((left: 0, top: 0, right: 20, bottom: 1400)),
    MapBlock((left: 1380, top: 0, right: 1400, bottom: 1400)),
    // 내부 높은 벽
    MapBlock((left: 280, top: 280, right: 700, bottom: 310)),
    MapBlock((left: 910, top: 490, right: 940, bottom: 910)),
    MapBlock((left: 210, top: 770, right: 490, bottom: 800)),
    MapBlock((left: 980, top: 1120, right: 1260, bottom: 1150)),
    // 낮은 상자 (격자 한 칸)
    MapBlock((left: 420, top: 560, right: 490, bottom: 630), low: true),
    MapBlock((left: 770, top: 770, right: 840, bottom: 840), low: true),
    MapBlock((left: 1120, top: 280, right: 1190, bottom: 350), low: true),
    MapBlock((left: 560, top: 1190, right: 630, bottom: 1260), low: true),
  ];
}
