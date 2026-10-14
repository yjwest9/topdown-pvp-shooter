import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/profile_repository.dart';
import 'package:topsoldier/ui/character/character_view.dart';

import '../../fakes.dart';

Future<void> pumpCharacters(
  WidgetTester tester, {
  int gold = 0,
  int diamond = 0,
}) async {
  tester.view
    ..physicalSize = const Size(740, 360)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = FakeRtdbService();
  final repo = ProfileRepository(db);
  await repo.create('u', 'A');
  await db.update('users/u', {'gold': gold, 'diamond': diamond});
  await repo.grantStarterCharacter('u', id: 'basic');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          AuthRepository(FakeAuthService('u')),
        ),
        profileRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: CharacterView()),
    ),
  );
  await tester.pump();
}

FilledButton buttonWith(WidgetTester tester, String text) => tester.widget(
  find.ancestor(of: find.text(text), matching: find.byType(FilledButton)),
);

void main() {
  testWidgets('740×360 with big numbers fits; basic soldier equipped', (
    tester,
  ) async {
    await pumpCharacters(tester, gold: 123456789, diamond: 99999);
    expect(find.text('123,456,789'), findsOneWidget);
    expect(find.text('기본 병사'), findsWidgets);
    expect(buttonWith(tester, '장착 중').onPressed, isNull);
    expect(find.text('강화 1단계마다 체력 +2'), findsOneWidget);
    expect(find.text('강화 +0 → +1'), findsOneWidget);
    // 미보유 셋은 위쪽 탭에 자물쇠(화면 구성을 바꿔 목록의 가격 대신).
    expect(find.byIcon(Icons.lock), findsNWidgets(3));
  });

  testWidgets('unowned: [구매], disabled when diamonds are short', (
    tester,
  ) async {
    await pumpCharacters(tester, diamond: 99);
    await tester.tap(find.text('정찰병'));
    await tester.pump();
    expect(buttonWith(tester, '다이아 부족 (100 다이아)').onPressed, isNull);
    expect(find.text('강화 +0 → +1'), findsNothing); // 미보유는 강화 없음
  });

  testWidgets('unowned with enough diamonds: [구매 100 다이아] works', (
    tester,
  ) async {
    await pumpCharacters(tester, diamond: 100);
    await tester.tap(find.text('정찰병'));
    await tester.pump();
    await tester.tap(find.text('구매 100 다이아'));
    await tester.pump();
    await tester.pump();
    expect(find.text('정찰병을(를) 샀습니다'), findsOneWidget);
    expect(find.text('장착'), findsWidgets);
  });
}
