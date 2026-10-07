import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/repositories/room_repository.dart';

import '../../fakes.dart';

/// 정해진 순서로 nextInt 값을 내는 Random.
class SeqRandom implements Random {
  SeqRandom(this.values);
  final List<int> values;
  var _i = 0;

  @override
  int nextInt(int max) => values[_i++ % values.length];

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}

void main() {
  test('room code is 4 digits', () {
    final r = Random(1);
    for (var i = 0; i < 200; i++) {
      expect(newRoomCode(r), matches(RegExp(r'^\d{4}$')));
    }
    expect(newRoomCode(SeqRandom([7])), '0007');
  });

  test('create: taken code is retried with another code', () async {
    final db = FakeRtdbService();
    await db.set('rooms/1234/meta', {'hostUid': 'other', 'status': 'waiting'});
    final repo = RoomRepository(db, random: SeqRandom([1234, 1234, 5678]));

    final code = await repo.createRoom(uid: 'host', name: 'A');

    expect(code, '5678');
    expect(await db.get('rooms/1234/meta/hostUid'), 'other'); // 안 덮어씀
    expect(await db.get('rooms/5678/meta/hostUid'), 'host');
    expect(await db.get('rooms/5678/players/host/connected'), true);
  });

  test('create: registers onDisconnect for connected flag and state', () async {
    final db = FakeRtdbService();
    final code = await RoomRepository(db).createRoom(uid: 'host', name: 'A');
    await db.set('rooms/$code/states/host', {'x': 1});

    db.disconnect();

    expect(await db.get('rooms/$code/players/host/connected'), false);
    expect(await db.get('rooms/$code/states/host'), isNull);
  });

  test('join: missing code throws', () async {
    final repo = RoomRepository(FakeRtdbService());
    expect(
      () => repo.joinRoom('9999', uid: 'b', name: 'B'),
      throwsA(isA<RoomException>()),
    );
  });

  test('join: full room throws', () async {
    final db = FakeRtdbService();
    final repo = RoomRepository(db);
    final code = await repo.createRoom(uid: 'a', name: 'A');
    await repo.joinRoom(code, uid: 'b', name: 'B');
    expect(
      () => repo.joinRoom(code, uid: 'c', name: 'C'),
      throwsA(isA<RoomException>()),
    );
  });

  test('players stream shows both after join', () async {
    final db = FakeRtdbService();
    final repo = RoomRepository(db);
    final code = await repo.createRoom(uid: 'a', name: 'A');
    await repo.joinRoom(code, uid: 'b', name: 'B');

    final players = await repo.players(code).first;
    expect(players.map((p) => p.uid), unorderedEquals(['a', 'b']));
  });
}
