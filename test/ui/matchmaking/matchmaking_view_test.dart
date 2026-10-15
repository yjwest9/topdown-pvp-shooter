import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/room_repository.dart';
import 'package:topsoldier/ui/lobby/lobby_view.dart';
import 'package:topsoldier/ui/matchmaking/matchmaking_view.dart';

import '../../fakes.dart';

/// 화면에 영어 원문(firebase 등)이 보이지 않는다.
void expectKoreanOnly(WidgetTester tester) {
  expect(find.text('인터넷 연결을 확인해 주세요'), findsOneWidget);
  expect(find.textContaining('firebase', findRichText: true), findsNothing);
  expect(find.textContaining('Failed', findRichText: true), findsNothing);
  expect(find.textContaining('Exception', findRichText: true), findsNothing);
}

List<Override> offline() => [
  authRepositoryProvider.overrideWithValue(
    AuthRepository(OfflineAuthService()),
  ),
  roomRepositoryProvider.overrideWithValue(RoomRepository(FakeRtdbService())),
];

void main() {
  testWidgets('quick match with no connection: one Korean line + 돌아가기', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: offline(),
        child: const MaterialApp(home: MatchmakingView()),
      ),
    );
    await tester.pump();
    expectKoreanOnly(tester);
    expect(find.text('돌아가기'), findsOneWidget);
  });

  testWidgets('create room with no connection: one Korean line', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: offline(),
        child: const MaterialApp(home: LobbyView()),
      ),
    );
    await tester.tap(find.text('방 만들기'));
    await tester.pumpAndSettle();
    expectKoreanOnly(tester);
  });

  testWidgets('join by code with no connection: one Korean line', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: offline(),
        child: const MaterialApp(home: LobbyView()),
      ),
    );
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('코드로 입장'));
    await tester.pumpAndSettle();
    expectKoreanOnly(tester);
  });
}
