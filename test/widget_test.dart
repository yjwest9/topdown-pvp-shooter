import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/game/soldier_game.dart';
import 'package:topsoldier/main.dart';

void main() {
  testWidgets('app shows the game', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TopSoldierApp()));
    expect(find.byType(RiverpodAwareGameWidget<SoldierGame>), findsOneWidget);
  });
}
