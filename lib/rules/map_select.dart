/// 고를 수 있는 맵(decisions 11장). 방 meta `map`에 [id]를 쓴다.
class MapInfo {
  const MapInfo({required this.id, required this.asset, required this.tiles});

  final String id;

  /// `assets/` 아래 Tiled 파일.
  final String asset;

  /// 한 변의 칸 수(70px 격자).
  final int tiles;

  /// 선택 칩에 쓰는 글자.
  String get label => '$id $tiles×$tiles';
}

const duelMap = MapInfo(id: 'duel', asset: 'maps/duel.tmx', tiles: 17);
const outpostMap = MapInfo(id: 'outpost', asset: 'maps/outpost.tmx', tiles: 31);

/// 봇전·친선전에서 고르는 맵. 맨 앞이 기본값.
const selectableMaps = [duelMap, outpostMap];

/// meta `map` 값 → 맵. 없거나 모르는 값이면 duel.
MapInfo mapById(Object? id) =>
    selectableMaps.firstWhere((m) => m.id == id, orElse: () => duelMap);
