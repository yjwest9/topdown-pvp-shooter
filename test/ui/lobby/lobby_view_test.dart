import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/room_repository.dart';
import 'package:topsoldier/ui/lobby/lobby_view.dart';

import '../../fakes.dart';

void main() {
  testWidgets('join by code → leave → code field is empty', (tester) async {
    final db = FakeRtdbService();
    final code = await RoomRepository(db).createRoom(uid: 'a', name: 'A');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            AuthRepository(FakeAuthService('b')),
          ),
          roomRepositoryProvider.overrideWithValue(RoomRepository(db)),
        ],
        child: const MaterialApp(home: LobbyView()),
      ),
    );

    await tester.enterText(find.byType(TextField), code);
    await tester.tap(find.text('코드로 입장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });

  testWidgets('map chips: duel is selected by default, outpost → waiting room '
      'shows the chosen map', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            AuthRepository(FakeAuthService('a')),
          ),
          roomRepositoryProvider.overrideWithValue(
            RoomRepository(FakeRtdbService()),
          ),
        ],
        child: const MaterialApp(home: LobbyView()),
      ),
    );

    ChoiceChip chip(String label) =>
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));
    expect(chip('duel 17×17').selected, isTrue);
    expect(chip('outpost 31×31').selected, isFalse);

    await tester.tap(find.text('outpost 31×31'));
    await tester.pump();
    await tester.tap(find.text('방 만들기'));
    await tester.pumpAndSettle();

    expect(find.text('맵 outpost 31×31'), findsOneWidget);
  });
}
