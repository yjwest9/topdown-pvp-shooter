import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';

import '../../rules/movement.dart';

class MapBlock {
  const MapBlock(this.box, {this.low = false});

  final Box box;

  /// 낮은 상자. 걸어서는 막히고 점프로 넘거나 올라선다.
  final bool low;
}

/// 팀 스폰 지점, 팀 진영 영역.
typedef MapSpawn = ({Vec pos, String team});
typedef MapBase = ({Box area, String team});

/// 벽·상자·스폰으로 된 맵. 바닥과 격자는 코드로 그린다.
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

  List<Vec> spawnsOf(String team) => [
    for (final s in spawns)
      if (s.team == team) s.pos,
  ];

  static final _floor = Paint()..color = const Color(0xFF3A4A3A);
  static final _grid = Paint()
    ..color = const Color(0xFF4A5C4A)
    ..strokeWidth = 1;
  static final _wall = Paint()..color = const Color(0xFF8A8F96);
  static final _lowBox = Paint()..color = const Color(0xFFB08850);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), _floor);
    for (var v = 0.0; v <= width; v += gridSize) {
      canvas.drawLine(Offset(v, 0), Offset(v, height), _grid);
    }
    for (var v = 0.0; v <= height; v += gridSize) {
      canvas.drawLine(Offset(0, v), Offset(width, v), _grid);
    }
    for (final b in blocks) {
      canvas.drawRect(
        Rect.fromLTRB(b.box.left, b.box.top, b.box.right, b.box.bottom),
        b.low ? _lowBox : _wall,
      );
    }
  }
}
