import 'dart:ui';

import 'package:flame/components.dart';

import '../../rules/movement.dart';

class MapBlock {
  const MapBlock(this.box, {this.low = false});

  final Box box;

  /// 낮은 상자. 지금은 벽처럼 막기만 한다(점프·엄폐는 다음 단계).
  final bool low;
}

/// 하드코딩 테스트 맵. 진영 맵(Tiled)은 나중에.
class TestMap extends Component {
  static const mapSize = 1400.0;
  static const gridSize = 70.0;
  static const spawn = (x: 700.0, y: 1000.0);

  final blocks = const <MapBlock>[
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

  late final List<Box> boxes = [for (final b in blocks) b.box];

  static final _floor = Paint()..color = const Color(0xFF3A4A3A);
  static final _grid = Paint()
    ..color = const Color(0xFF4A5C4A)
    ..strokeWidth = 1;
  static final _wall = Paint()..color = const Color(0xFF8A8F96);
  static final _lowBox = Paint()..color = const Color(0xFFB08850);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(const Rect.fromLTWH(0, 0, mapSize, mapSize), _floor);
    for (var v = 0.0; v <= mapSize; v += gridSize) {
      canvas
        ..drawLine(Offset(v, 0), Offset(v, mapSize), _grid)
        ..drawLine(Offset(0, v), Offset(mapSize, v), _grid);
    }
    for (final b in blocks) {
      canvas.drawRect(
        Rect.fromLTRB(b.box.left, b.box.top, b.box.right, b.box.bottom),
        b.low ? _lowBox : _wall,
      );
    }
  }
}
