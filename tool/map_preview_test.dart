// 맵 미리보기 그림 만들기. 일반 테스트(test/)에는 넣지 않는다.
//   flutter test tool/map_preview_test.dart
// → docs/maps/<맵 이름>.png (게임과 같은 GameMap.render + 스폰·진영 표시, 0.3배)
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/game/components/game_map.dart';

void main() {
  for (final name in ['outpost', 'duel']) {
    testWidgets('render docs/maps/$name.png', (tester) async {
      final map = GameMap.fromTmx(
        File('assets/maps/$name.tmx').readAsStringSync(),
      );
      const scale = 0.3;
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder)..scale(scale);
      // 맵은 게임 안에서 그림 타일로 한 장에 구워지므로(GameMap.onLoad) 여기선 단순한 색으로 그린다.
      canvas.drawRect(
        Rect.fromLTWH(0, 0, map.width, map.height),
        Paint()..color = const Color(0xFF3A3F3C),
      );
      final cells = Paint()..color = const Color(0xFFA9C4C8);
      for (var y = 0.0; y < map.height; y += GameMap.gridSize) {
        for (var x = 0.0; x < map.width; x += GameMap.gridSize) {
          final c = Offset(x + GameMap.gridSize / 2, y + GameMap.gridSize / 2);
          // 걸을 수 있는 칸(높은 벽이 아닌 칸)만 바닥색.
          final walled = map.highWalls.any(
            (b) =>
                c.dx > b.left &&
                c.dx < b.right &&
                c.dy > b.top &&
                c.dy < b.bottom,
          );
          if (!walled) {
            canvas.drawRect(
              Rect.fromLTWH(x, y, GameMap.gridSize, GameMap.gridSize),
              cells,
            );
          }
        }
      }
      for (final b in map.highWalls) {
        canvas.drawRect(
          Rect.fromLTRB(b.left, b.top, b.right, b.bottom),
          Paint()..color = const Color(0xFF2B2F2D),
        );
      }
      for (final b in map.lowCrates) {
        canvas.drawRect(
          Rect.fromLTRB(b.left + 6, b.top + 6, b.right - 6, b.bottom - 6),
          Paint()..color = const Color(0xFFD9822B),
        );
      }
      for (final b in map.bases) {
        canvas.drawRect(
          Rect.fromLTRB(b.area.left, b.area.top, b.area.right, b.area.bottom),
          Paint()
            ..color = b.team == 'A'
                ? const Color(0x334FA3E0)
                : const Color(0x33E0563F),
        );
      }
      for (final s in map.spawns) {
        canvas.drawCircle(
          Offset(s.pos.x, s.pos.y),
          22,
          Paint()
            ..color = s.team == 'A'
                ? const Color(0xFF4FA3E0)
                : const Color(0xFFE0563F),
        );
      }
      final picture = recorder.endRecording();
      await tester.runAsync(() async {
        final image = await picture.toImage(
          (map.width * scale).round(),
          (map.height * scale).round(),
        );
        final png = await image.toByteData(format: ImageByteFormat.png);
        File('docs/maps/$name.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
    });
  }
}
