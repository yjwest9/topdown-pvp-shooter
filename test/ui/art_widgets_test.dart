import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/ui/character_figure.dart';
import 'package:topsoldier/ui/weapon_art_view.dart';

/// 코드로 그리는 그림(decisions 8장·17장)이 모든 무기·캐릭터 조합에서 예외 없이 그려진다.
void main() {
  testWidgets('every weapon draws, big and small', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Wrap(
          children: [
            for (final w in weapons) ...[
              WeaponArt(w.id, width: 220, height: 64),
              WeaponArt(w.id, width: 56, height: 28, dim: true),
            ],
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(WeaponArt), findsNWidgets(weapons.length * 2));
  });

  testWidgets('every character stands with every weapon, or none', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(3000, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Wrap(
          children: [
            for (final c in characters) ...[
              CharacterFigure(c.id, height: 120),
              for (final w in weapons)
                CharacterFigure(c.id, height: 120, weaponId: w.id),
            ],
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(CharacterFigure).first),
      const Size(75, 120),
    );
  });
}
