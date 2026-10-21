import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:topsoldier/data/repositories/ad_repository.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/profile_repository.dart';
import 'package:topsoldier/ui/home/home_view.dart';
import 'package:topsoldier/ui/home/home_view_model.dart';

import '../../fakes.dart';

const notice = '지난 대전을 끝내지 않고 나가 패배로 기록되었습니다.';

/// 앱을 (다시) 켠다. 같은 [db]면 같은 서버 데이터로 시작.
Future<void> launch(WidgetTester tester, FakeRtdbService db) async {
  tester.view
    ..physicalSize = const Size(740, 360)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(), // 앱을 새로 켠 것처럼 상태를 버린다
      overrides: [
        adRepositoryProvider.overrideWithValue(AdRepository(FakeAdService())),
        authRepositoryProvider.overrideWithValue(
          AuthRepository(FakeAuthService('u')),
        ),
        profileRepositoryProvider.overrideWithValue(ProfileRepository(db)),
        holidayProvider.overrideWith((ref) => null),
      ],
      child: const MaterialApp(home: HomeView()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<FakeRtdbService> profileWithLeftover() async {
  final db = FakeRtdbService();
  final repo = ProfileRepository(db);
  await repo.create('u', '병사');
  await repo.grantStarter('u', primary: 'rifle_standard', secondary: 'pistol');
  await repo.grantStarterCharacter('u', id: 'basic');
  await db.update('users/u', {'gold': 4000});
  await repo.setActiveMatch('u', 'room1-9000'); // 강제 종료로 남은 표시
  return db;
}

void main() {
  testWidgets('restart with a leftover marker: one loss (no reward), marker '
      'cleared, notice shown once', (tester) async {
    final db = await profileWithLeftover();
    await launch(tester, db);

    expect(find.text(notice), findsOneWidget);
    final u = (await db.get('users/u'))! as Map;
    expect((u['stats'] as Map)['matches'], 1);
    expect((u['stats'] as Map)['wins'], 0);
    expect(u['gold'], 4000);
    expect(u['exp'], 0);
    expect(u['lastMatchId'], 'room1-9000');
    expect(u.containsKey('activeMatch'), false);

    // 한 번 더 껐다 켜도 1패 그대로, 안내도 없다.
    await tester.pump(const Duration(seconds: 6)); // 안내가 사라진 뒤
    await launch(tester, db);
    expect(find.text(notice), findsNothing);
    expect(((await db.get('users/u/stats'))! as Map)['matches'], 1);
  });

  testWidgets('marker of a match that was already saved: no loss, no notice, '
      'marker removed', (tester) async {
    final db = await profileWithLeftover();
    await db.update('users/u', {'lastMatchId': 'room1-9000'});
    await launch(tester, db);

    expect(find.text(notice), findsNothing);
    expect(((await db.get('users/u/stats'))! as Map)['matches'], 0);
    expect(await db.get('users/u/activeMatch'), isNull);
  });

  testWidgets('no marker (finished normally): no notice', (tester) async {
    final db = await profileWithLeftover();
    await db.update('users/u', {'activeMatch': null});
    await launch(tester, db);

    expect(find.text(notice), findsNothing);
    expect(((await db.get('users/u/stats'))! as Map)['matches'], 0);
  });
}
