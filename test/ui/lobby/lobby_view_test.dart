import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/room_repository.dart';
import 'package:topsoldier/ui/lobby/lobby_view.dart';
import 'package:topsoldier/ui/lobby/lobby_view_model.dart';

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
          holidayProvider.overrideWith((ref) => null),
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
}
