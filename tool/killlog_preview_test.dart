// 킬 로그 예시(K2·칼·M870·모르는 id) 미리보기. 일반 테스트(test/)에는 넣지 않는다.
//   flutter test tool/killlog_preview_test.dart
// → build/tmp/killlog.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/game/components/match_hud.dart';

void main() {
  testWidgets('render build/tmp/killlog.png', (tester) async {
    await tester.runAsync(() async {
      const w = 260.0, h = 76.0, scale = 4.0;
      final rec = ui.PictureRecorder();
      final canvas = ui.Canvas(rec)
        ..scale(scale)
        ..drawRect(
          const ui.Rect.fromLTWH(0, 0, w, h),
          ui.Paint()..color = const ui.Color(0xFF6B7F52),
        );
      const lines = [
        ('Alpha', 'Bravo', 'rifle_standard', false),
        ('Alpha', 'Bravo', 'knife', false),
        ('Alpha', 'Bravo', 'shotgun_pump', true),
        ('Alpha', 'Bravo', 'mystery_gun', false),
      ];
      for (final (i, l) in lines.indexed) {
        MatchHud.paintKillLine(
          canvas,
          Offset(w - 8, 4 + i * 18.0),
          l.$1,
          l.$2,
          l.$3,
          crit: l.$4,
        );
      }
      final image = await rec.endRecording().toImage(
        (w * scale).round(),
        (h * scale).round(),
      );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('build/tmp/killlog.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
