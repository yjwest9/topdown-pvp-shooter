// 홈·캐릭터 화면 정면 그림 미리보기. 일반 테스트(test/)에는 넣지 않는다.
//   flutter test tool/figure_preview_test.dart
// → build/figure_preview.png (캐릭터 4종 × 무기 몇 가지, 홈 배경색)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/ui/character_figure.dart';
import 'package:topsoldier/ui/style.dart';

void main() {
  testWidgets('render build/figure_preview.png', (tester) async {
    tester.view
      ..physicalSize = const Size(1700, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    const guns = [
      null,
      'rifle_standard',
      'sniper_bolt',
      'shotgun_pump',
      'pistol',
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: Container(
            color: bgColor,
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    for (final c in characters)
                      Row(
                        children: [
                          for (final g in guns)
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: CharacterFigure(
                                c.id,
                                height: 320,
                                weaponId: g,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
                const CharacterFigure(
                  'basic',
                  height: 900,
                  weaponId: 'sniper_bolt',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('build/figure_preview.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
