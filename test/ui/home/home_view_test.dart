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
}
