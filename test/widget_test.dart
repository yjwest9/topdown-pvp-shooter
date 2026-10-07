import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/game/soldier_game.dart';
import 'package:topsoldier/main.dart';

void main() {
  testWidgets('lobby → 훈련소 opens the offline game without Firebase', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: TopSoldierApp()));
    expect(find.text('방 만들기'), findsOneWidget);

    await tester.tap(find.text('훈련소'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final game = tester
        .widget<RiverpodAwareGameWidget<SoldierGame>>(
          find.byType(RiverpodAwareGameWidget<SoldierGame>),
        )
        .game!;
    expect(game.match, isNull);
  });
}
