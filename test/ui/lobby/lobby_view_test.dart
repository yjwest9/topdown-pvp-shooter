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

  Future<FakeRtdbService> openLobby(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(900, 600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeRtdbService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            AuthRepository(FakeAuthService('a')),
          ),
          roomRepositoryProvider.overrideWithValue(
            RoomRepository(db, clock: () => db.serverTime),
          ),
        ],
        child: const MaterialApp(home: LobbyView()),
      ),
    );
    return db;
  }

  ChoiceChip chipOf(WidgetTester tester, String label) =>
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));

  testWidgets('team size chips: 1v1 by default; 2v2 locks the map to outpost '
      '(duel chip disabled)', (tester) async {
    await openLobby(tester);
    expect(chipOf(tester, '1대1').selected, isTrue);
    expect(chipOf(tester, '2대2').selected, isFalse);
    expect(chipOf(tester, 'duel 17×17').onSelected, isNotNull);

    await tester.tap(find.text('2대2'));
    await tester.pump();
    expect(chipOf(tester, '2대2').selected, isTrue);
    expect(chipOf(tester, 'outpost 31×31').selected, isTrue);
    expect(chipOf(tester, 'duel 17×17').onSelected, isNull); // 비활성

    await tester.tap(find.text('1대1'));
    await tester.pump();
    expect(chipOf(tester, 'duel 17×17').onSelected, isNotNull);
  });

  testWidgets('2v2 waiting room: team columns with empty seats; the start '
      'button waits for the 4th player', (tester) async {
    await openLobby(tester);
    await tester.tap(find.text('2대2'));
    await tester.pump();
    await tester.tap(find.text('방 만들기'));
    await tester.pumpAndSettle();

    expect(find.text('A팀 (내 팀)'), findsOneWidget);
    expect(find.text('B팀'), findsOneWidget);
    expect(find.text('빈자리'), findsNWidgets(3)); // A 1칸 + B 2칸
    expect(find.text('맵 outpost 31×31'), findsOneWidget);
    expect(find.text(' · 2대2'), findsOneWidget);
    final start = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '상대를 기다리는 중'),
    );
    expect(start.onPressed, isNull);
    expect(find.text('이 팀으로'), findsOneWidget); // B에 빈자리 → 옮길 수 있다
  });

  testWidgets('1v1 waiting room keeps the old shape: one seat per team, '
      'start waits for the opponent', (tester) async {
    await openLobby(tester);
    await tester.tap(find.text('방 만들기'));
    await tester.pumpAndSettle();

    expect(find.text('빈자리'), findsOneWidget); // B 1칸
    expect(find.text(' · 1대1'), findsOneWidget);
    expect(find.text('상대를 기다리는 중'), findsOneWidget);
  });

  testWidgets('swap button next to a player on the other team: request → '
      '"요청 중" with cancel', (tester) async {
    final db = await openLobby(tester);
    await tester.tap(find.text('2대2'));
    await tester.pump();
    await tester.tap(find.text('방 만들기'));
    await tester.pumpAndSettle();
    final room = ((await db.get('rooms'))! as Map).keys.single as String;
    await RoomRepository(db).joinRoom(room, uid: 'b', name: '상대');
    await tester.pumpAndSettle();

    expect(find.text('상대'), findsOneWidget);
    final swap = find.widgetWithText(TextButton, '자리 바꾸기');
    expect(tester.widget<TextButton>(swap).onPressed, isNotNull);
    await tester.tap(swap);
    await tester.pumpAndSettle();
    expect(find.text('상대님에게 자리 바꾸기 요청 중…'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '취소'));
    await tester.pumpAndSettle();
    expect(find.text('상대님에게 자리 바꾸기 요청 중…'), findsNothing);
  });
}
