import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/foundation.dart';

import '../../rules/appearance.dart';
import '../../rules/movement.dart';
import '../game_art.dart';

class MapBlock {
  const MapBlock(this.box, {this.low = false});

  final Box box;

  /// 낮은 상자. 걸어서는 막히고 점프로 넘거나 올라선다.
  final bool low;
}

/// 팀 스폰 지점, 팀 진영 영역.
typedef MapSpawn = ({Vec pos, String team});
typedef MapBase = ({Box area, String team});

/// 벽·상자·스폰으로 된 맵. 바닥·벽·상자는 타일 그림으로, 게임에 들어올 때 맵 전체를
/// 한 장의 그림으로 미리 그려 두고 매 프레임 그 한 장만 그린다(칸이 961개라서).
class GameMap extends Component {
  GameMap({
    required this.width,
    required this.height,
    required this.blocks,
    this.spawns = const [],
    this.bases = const [],
  });

  /// Tiled 맵(타일 없음, 오브젝트 레이어만):
  /// walls·crates = 사각형, spawns = 점 + 속성 team, bases = 사각형 + 속성 team.
  factory GameMap.fromTmx(String xml) {
    final tiled = TileMapParser.parseTmx(xml);
    List<TiledObject> layer(String name) =>
        tiled.layerByName(name) is ObjectGroup
        ? (tiled.layerByName(name) as ObjectGroup).objects
        : const [];
    Box box(TiledObject o) =>
        (left: o.x, top: o.y, right: o.x + o.width, bottom: o.y + o.height);
    String team(TiledObject o) => o.properties.getValue<String>('team') ?? '';
    return GameMap(
      width: (tiled.width * tiled.tileWidth).toDouble(),
      height: (tiled.height * tiled.tileHeight).toDouble(),
      blocks: [
        for (final o in layer('walls')) MapBlock(box(o)),
        for (final o in layer('crates')) MapBlock(box(o), low: true),
      ],
      spawns: [
        for (final o in layer('spawns')) (pos: (x: o.x, y: o.y), team: team(o)),
      ],
      bases: [for (final o in layer('bases')) (area: box(o), team: team(o))],
    );
  }

  static const gridSize = 70.0;

  final double width;
  final double height;
  final List<MapBlock> blocks;
  final List<MapSpawn> spawns;
  final List<MapBase> bases;

  late final List<Box> highWalls = [
    for (final b in blocks)
      if (!b.low) b.box,
  ];
  late final List<Box> lowCrates = [
    for (final b in blocks)
      if (b.low) b.box,
  ];

  /// 맵 가운데에서 걸을 수 있는 칸(높은 벽이 없는 칸)의 가장 먼 모서리까지 거리.
  /// 미니맵 원이 이 반지름으로 맵 전체를 담는다.
  late final double reach = () {
    var far = 0.0;
    final cols = (width / gridSize).ceil(), rows = (height / gridSize).ceil();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cell = (
          left: c * gridSize,
          top: r * gridSize,
          right: (c + 1) * gridSize,
          bottom: (r + 1) * gridSize,
        );
        final walled = highWalls.any(
          (w) =>
              w.left < cell.right &&
              cell.left < w.right &&
              w.top < cell.bottom &&
              cell.top < w.bottom,
        );
        if (walled) continue;
        for (final (x, y) in [
          (cell.left, cell.top),
          (cell.right, cell.top),
          (cell.left, cell.bottom),
          (cell.right, cell.bottom),
        ]) {
          far = max(far, sqrt(pow(x - width / 2, 2) + pow(y - height / 2, 2)));
        }
      }
    }
    return far;
  }();

  List<Vec> spawnsOf(String team) => [
    for (final s in spawns)
      if (s.team == team) s.pos,
  ];

  Image? _baked;

  /// 미리 그려 둔 맵 전체 그림(게임에 붙은 뒤). 테스트가 확인하는 용도.
  @visibleForTesting
  Image? get bakedImage => _baked;

  /// 게임에 붙을 때 한 번: 타일을 불러와 맵 전체를 그려 둔다. 게임 밖(테스트의 맵 모양
  /// 확인)에서는 그림이 필요 없어서 건너뛴다.
  @override
  Future<void> onLoad() async {
    final game = findGame();
    if (game == null) return;
    final art = GameArt(game.images);
    final loading = art.load();
    if (loading != null) await loading;
    _baked = _bake(art);
  }

  Image _bake(GameArt art) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final cols = (width / gridSize).ceil(), rows = (height / gridSize).ceil();
    final floors = [for (final f in floorTiles) art.tile(f)];
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        // 같은 타일만 깔리면 격자처럼 보여서 두 가지를 섞는다(고정 패턴).
        final tile = floors[(c * 7 + r * 3) % 4 == 0 ? 1 : 0];
        _drawTile(
          canvas,
          tile,
          c * gridSize,
          r * gridSize,
          gridSize,
          gridSize,
          paint,
        );
      }
    }
    // 그림자: 높은 벽은 길게, 낮은 상자는 짧게 → 높이 차이가 한눈에 보인다(decisions 4장).
    // 타일을 그리기 전에 전부 깔아서 옆 칸 타일을 덮지 않게 한다.
    final shadow = Paint()..color = const Color(0x66000000);
    for (final (boxes, dx, dy) in [
      (highWalls, 8.0, 10.0),
      (lowCrates, 3.0, 4.0),
    ]) {
      for (final b in boxes) {
        canvas.drawRect(
          Rect.fromLTRB(b.left + dx, b.top + dy, b.right + dx, b.bottom + dy),
          shadow,
        );
      }
    }
    for (final (box, tile) in [
      for (final b in highWalls) (b, art.tile(wallTile)),
      for (final b in lowCrates) (b, art.tile(crateTile)),
    ]) {
      // 상자·벽 사각형을 칸 단위로 타일로 채운다(칸에 안 맞는 가장자리는 잘라서).
      for (var y = box.top; y < box.bottom; y += gridSize) {
        for (var x = box.left; x < box.right; x += gridSize) {
          _drawTile(
            canvas,
            tile,
            x,
            y,
            min(gridSize, box.right - x),
            min(gridSize, box.bottom - y),
            paint,
          );
        }
      }
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width.ceil(), height.ceil());
    picture.dispose();
    return image;
  }

  /// 64px 타일 그림의 왼쪽 위 [w]×[h]/[gridSize] 만큼을 (x, y)에 [w]×[h]로 그린다.
  static void _drawTile(
    Canvas canvas,
    Image tile,
    double x,
    double y,
    double w,
    double h,
    Paint paint,
  ) => canvas.drawImageRect(
    tile,
    Rect.fromLTWH(0, 0, tile.width * w / gridSize, tile.height * h / gridSize),
    Rect.fromLTWH(x, y, w, h),
    paint,
  );

  @override
  void render(Canvas canvas) {
    final baked = _baked;
    if (baked != null) canvas.drawImage(baked, Offset.zero, Paint());
  }

  @override
  void onRemove() {
    _baked?.dispose();
    _baked = null;
  }
}
