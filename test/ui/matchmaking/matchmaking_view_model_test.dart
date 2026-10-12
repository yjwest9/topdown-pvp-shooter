import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/room_repository.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/ui/matchmaking/matchmaking_view_model.dart';

import '../../fakes.dart';

const slotPath = 'matchmaking/1v1/waiting';

/// 화면을 연 것처럼 provider를 살려 둔다. 타이머가 남지 않게 테스트 끝에 [ProviderContainer.dispose].
ProviderContainer player(String uid, FakeRtdbService db) {
  final c = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        AuthRepository(FakeAuthService(uid)),
      ),
      roomRepositoryProvider.overrideWithValue(RoomRepository(db)),
    ],
  );
  c.listen(matchmakingProvider, (_, _) {});
  return c;
}

MatchmakingState stateOf(ProviderContainer c) => c.read(matchmakingProvider);

void main() {
  testWidgets('two players press at once → one claims, one takes, same room, '
      'starts after the countdown', (tester) async {
    final db = FakeRtdbService();
    final a = player('a', db);
    final b = player('b', db);
    await tester.pump();

    final sa = stateOf(a);
    final sb = stateOf(b);
    expect(sa.found && sb.found, true);
    expect(sa.roomId, isNotNull);
    expect(sa.roomId, sb.roomId);
    expect([sa.isHost, sb.isHost]..sort((x, y) => x ? 1 : -1), [false, true]);
    expect(sa.opponent, isNotEmpty);
    expect(await db.get(slotPath), isNull); // 방장이 대기석을 비움
    final rooms = (await db.get('rooms'))! as Map;
    expect(rooms.keys, [sa.roomId]); // 잡은 쪽이 만든 방은 지워짐
    expect(stateOf(a).started, false);

    await tester.pump(const Duration(seconds: quickMatchCountdown));
    expect(stateOf(a).started && stateOf(b).started, true);
    a.dispose();
    b.dispose();
  });

  testWidgets('cancel removes my slot and my room', (tester) async {
    final db = FakeRtdbService();
    final a = player('a', db);
    await tester.pump();
    final slot = (await db.get(slotPath))! as Map;
    expect(slot['uid'], 'a');
    expect(await db.get('rooms/${slot['roomId']}/meta'), isNotNull);

    await a.read(matchmakingProvider.notifier).cancel();
    expect(await db.get(slotPath), isNull);
    expect(await db.get('rooms'), anyOf(isNull, isEmpty));

    // 다시 누르면 정상 대기
    final again = player('a', db);
    await tester.pump();
    expect(((await db.get(slotPath))! as Map)['uid'], 'a');
    a.dispose();
    again.dispose();
  });

  testWidgets('app killed while waiting → slot and room are gone, '
      'the next player sits down', (tester) async {
    final db = FakeRtdbService();
    final a = player('a', db);
    await tester.pump();
    db.disconnect();
    expect(await db.get(slotPath), isNull);
    expect(await db.get('rooms'), anyOf(isNull, isEmpty));
    a.dispose();

    final b = player('b', db);
    await tester.pump();
    expect(((await db.get(slotPath))! as Map)['uid'], 'b');
    expect(stateOf(b).found, false);
    b.dispose();
  });

  testWidgets('stale slot of someone gone is taken over', (tester) async {
    final db = FakeRtdbService();
    await db.set(slotPath, {
      'uid': 'ghost',
      'roomId': 'old',
      'name': 'G',
      't': DateTime.now().millisecondsSinceEpoch - quickMatchStaleMs - 1,
    });
    final b = player('b', db);
    await tester.pump();
    expect(((await db.get(slotPath))! as Map)['uid'], 'b');
    b.dispose();
  });

  testWidgets('heartbeat refreshes my slot every 5 seconds', (tester) async {
    final db = FakeRtdbService();
    final a = player('a', db);
    await tester.pump();
    final before = db.writes[slotPath]!;

    await tester.pump(quickMatchHeartbeat - const Duration(milliseconds: 100));
    expect(db.writes[slotPath], before);
    await tester.pump(const Duration(milliseconds: 100));
    expect(db.writes[slotPath], before + 1);
    await tester.pump(quickMatchHeartbeat);
    expect(db.writes[slotPath], before + 2);
    a.dispose();
  });

  testWidgets('bot button shows up after 30 seconds of waiting', (
    tester,
  ) async {
    final db = FakeRtdbService();
    final a = player('a', db);
    await tester.pump();
    await tester.pump(quickMatchBotOffer - const Duration(seconds: 1));
    expect(stateOf(a).offerBot, false);
    await tester.pump(const Duration(seconds: 1));
    expect(stateOf(a).offerBot, true);
    a.dispose();
  });

  testWidgets('taken but nobody comes within 10 seconds → search again '
      'with a new room', (tester) async {
    final db = FakeRtdbService();
    final a = player('a', db);
    await tester.pump();
    final oldRoom = ((await db.get(slotPath))! as Map)['roomId'];

    // 누가 잡았지만(takenBy) 방에 들어오지 않는다.
    await db.update(slotPath, {'takenBy': 'ghost'});
    expect(await db.get(slotPath), isNull); // 잡히면 대기석을 비움

    await tester.pump(quickMatchTakenTimeout - const Duration(seconds: 1));
    expect(await db.get(slotPath), isNull);
    expect(await db.get('rooms/$oldRoom'), isNotNull);

    await tester.pump(const Duration(seconds: 1));
    final slot = (await db.get(slotPath))! as Map;
    expect(slot['uid'], 'a');
    expect(slot['roomId'], isNot(oldRoom));
    expect(await db.get('rooms/$oldRoom'), isNull);
    expect(stateOf(a).found, false);
    a.dispose();
  });
}
