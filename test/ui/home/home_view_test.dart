import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:topsoldier/data/models/holiday.dart';
import 'package:topsoldier/data/repositories/ad_repository.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/profile_repository.dart';
import 'package:topsoldier/ui/home/home_view.dart';
import 'package:topsoldier/ui/home/home_view_model.dart';

import '../../fakes.dart';

void main() {
  testWidgets('small landscape phone: long nickname and big numbers fit, '
      'the 캐릭터 menu opens the character screen', (tester) async {
    tester.view
      ..physicalSize = const Size(740, 360)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final db = FakeRtdbService();
    await ProfileRepository(db).create('u', '가나다라마바사아자차카타');
    await db.update('users/u', {'gold': 123456789, 'diamond': 99999});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adRepositoryProvider.overrideWithValue(AdRepository(FakeAdService())),
          authRepositoryProvider.overrideWithValue(
            AuthRepository(FakeAuthService('u')),
          ),
          profileRepositoryProvider.overrideWithValue(ProfileRepository(db)),
          holidayProvider.overrideWith(
            (ref) => Holiday(date: DateTime(2026, 10, 9), name: '한글날'),
          ),
        ],
        child: const MaterialApp(home: HomeView()),
      ),
    );
    await tester.pump();

    expect(find.text('123,456,789'), findsOneWidget);
    expect(find.textContaining('공휴일 보상 2배'), findsOneWidget);
    await tester.tap(find.text('캐릭터'));
    await tester.pumpAndSettle();
    expect(find.text('저격수'), findsOneWidget);
  });

  /// 처음엔 오프라인(로그인 실패), 곧 온라인이 되는 첫 실행. [withProfile]이면 서버에 프로필이 있다.
  Future<void> pumpOfflineThenOnline(
    WidgetTester tester, {
    required bool withProfile,
  }) async {
    tester.view
      ..physicalSize = const Size(740, 360)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final db = FakeRtdbService();
    if (withProfile) await ProfileRepository(db).create('u', '병사');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adRepositoryProvider.overrideWithValue(AdRepository(FakeAdService())),
          authRepositoryProvider.overrideWithValue(
            // Riverpod이 자체로 10번쯤 다시 시도하다 포기한 뒤에도(약 40초) 온라인이 되면 돌아와야 한다.
            AuthRepository(FlakyAuthService('u', failures: 14)),
          ),
          profileRepositoryProvider.overrideWithValue(ProfileRepository(db)),
          holidayProvider.overrideWith((ref) => null),
        ],
        child: const MaterialApp(home: HomeView()),
      ),
    );
    await tester.pump();
  }

  Future<void> waitOnline(WidgetTester tester) async {
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('offline first run → connection returns, no profile: '
      'the nickname form appears', (tester) async {
    await pumpOfflineThenOnline(tester, withProfile: false);
    expect(find.text('빠른 대전'), findsOneWidget); // 오프라인 홈(임시 닉네임)
    expect(find.text('닉네임을 정해 주세요'), findsNothing);

    await waitOnline(tester);
    expect(find.text('닉네임을 정해 주세요'), findsOneWidget);
  });

  testWidgets('offline first run → connection returns, profile exists: '
      'no nickname form', (tester) async {
    await pumpOfflineThenOnline(tester, withProfile: true);
    await waitOnline(tester);
    expect(find.text('닉네임을 정해 주세요'), findsNothing);
    expect(find.text('빠른 대전'), findsOneWidget);
    expect(find.text('병사'), findsOneWidget); // 프로필 닉네임으로 바뀜
  });
}
