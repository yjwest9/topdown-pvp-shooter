import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/game/components/match_hud.dart';

/// 킬 로그 한 줄을 300x20 그림에 그려 (그림 반환값, 무기 그림 자리에 칠한 픽셀이 있는지)를 돌려준다.
Future<(bool, bool)> render(String killer, String weapon) async {
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  final drew = MatchHud.paintKillLine(
    canvas,
    const Offset(290, 2),
    killer,
    'B',
    weapon,
  );
  final img = await rec.endRecording().toImage(300, 20);
  final data = (await img.toByteData())!;
  var inked = false;
  for (var y = 0; y < 20; y++) {
    for (var x = 232; x < 276; x++) {
      if (data.getUint8((y * 300 + x) * 4 + 3) > 0) inked = true;
    }
  }
  return (drew, inked);
}

void main() {
  testWidgets('known weapon id draws the weapon picture between the names', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // 처치자 글자는 그림 왼쪽에만 있으므로 비워 두면 그림 자리의 픽셀은 무기 그림 것이다.
      expect(await render('', 'rifle_standard'), (true, true));
      expect(await render('', 'knife'), (true, true));
      expect(await render('', 'shotgun_pump'), (true, true));
    });
  });

  testWidgets('unknown weapon id falls back to text, no picture', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (drew, _) = await render('A', 'mystery_gun');
      expect(drew, false);
    });
  });
}
