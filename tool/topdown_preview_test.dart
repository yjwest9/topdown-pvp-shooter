// 게임 안 병사(위에서 본 모습) 미리보기. 일반 테스트(test/)에는 넣지 않는다.
//   flutter test tool/topdown_preview_test.dart
// → build/topdown_preview.png (실제 바닥 타일 위, 캐릭터 4종 × 포즈 5개. 위 줄 4배, 아래 줄 게임 크기)
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/game/soldier_art.dart';
import 'package:topsoldier/rules/appearance.dart';
import 'package:topsoldier/rules/balance.dart';

void main() {
  testWidgets('render build/topdown_preview.png', (tester) async {
    await tester.runAsync(() async {
      final codec = await instantiateImageCodec(
        File('assets/images/tile_07.png').readAsBytesSync(),
      );
      final tile = (await codec.getNextFrame()).image;
      const cell = 160.0, small = 48.0;
      final w = cell * Pose.values.length, h = cell * characters.length;
      final rec = PictureRecorder();
      final canvas = Canvas(rec);
      for (var x = 0.0; x < w; x += 70) {
        for (var y = 0.0; y < h + small * characters.length; y += 70) {
          canvas.drawImageRect(
            tile,
            const Rect.fromLTWH(0, 0, 64, 64),
            Rect.fromLTWH(x, y, 70, 70),
            Paint(),
          );
        }
      }
      void soldier(Offset at, double scale, String id, Pose pose) {
        canvas
          ..save()
          ..translate(at.dx, at.dy)
          ..scale(scale)
          // 게임처럼 발밑 팀 원(내 팀 파랑)
          ..drawCircle(
            Offset.zero,
            playerRadius,
            Paint()..color = const Color(0x554FA3E0),
          )
          ..drawCircle(
            Offset.zero,
            playerRadius,
            Paint()
              ..color = const Color(0xFF4FA3E0)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3,
          );
        SoldierArt.draw(canvas, id, pose);
        canvas.restore();
      }

      for (final (row, c) in characters.indexed) {
        for (final (col, p) in Pose.values.indexed) {
          soldier(
            Offset(col * cell + cell / 2, row * cell + cell / 2),
            4,
            c.id,
            p,
          );
          soldier(
            Offset(col * cell + cell / 2, h + row * small + small / 2),
            1,
            c.id,
            p,
          );
        }
      }
      final image = await rec.endRecording().toImage(
        w.round(),
        (h + small * characters.length).round(),
      );
      final png = await image.toByteData(format: ImageByteFormat.png);
      File('build/topdown_preview.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
