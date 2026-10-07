// 맵 미리보기 그림 만들기. 일반 테스트(test/)에는 넣지 않는다.
//   flutter test tool/map_preview_test.dart
// → docs/maps/frontline.png (게임과 같은 GameMap.render + 스폰·진영 표시, 0.3배)
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/game/components/game_map.dart';

void main() {
  testWidgets('render docs/maps/frontline.png', (tester) async {
    final map = GameMap.fromTmx(
      File('assets/maps/frontline.tmx').readAsStringSync(),
    );
    const scale = 0.3;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    map.render(canvas);
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
      File('docs/maps/frontline.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
