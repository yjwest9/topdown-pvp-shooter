import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/models/room.dart';
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

  test('create: meta map defaults to duel, host can pick outpost', () async {
    final db = FakeRtdbService();
    final repo = RoomRepository(db);
    final a = await repo.createRoom(uid: 'a', name: 'A');
    final b = await repo.createRoom(uid: 'b', name: 'B', map: 'outpost');

    expect(await db.get('rooms/$a/meta/map'), 'duel');
    expect(await db.get('rooms/$b/meta/map'), 'outpost');
    expect((await repo.meta(b).first)!.map, 'outpost');
  });

  group('2v2 friendly room (decisions 12장)', () {
    Future<String> room2v2(FakeRtdbService db, RoomRepository repo) =>
        repo.createRoom(uid: 'h', name: 'H', teamSize: 2, map: 'outpost');

    Future<Map<String, String>> teams(FakeRtdbService db, String code) async {
      final ps = (await db.get('rooms/$code/players'))! as Map;
      return {
        for (final e in ps.entries)
          e.key as String: (e.value as Map)['team'] as String,
      };
    }

    test('meta carries teamSize; a room without it reads as 1', () async {
      final db = FakeRtdbService();
      final repo = RoomRepository(db);
      final one = await repo.createRoom(uid: 'a', name: 'A');
      final two = await room2v2(db, repo);
      expect(await db.get('rooms/$one/meta/teamSize'), 1);
      expect(await db.get('rooms/$two/meta/teamSize'), 2);
      expect((await repo.meta(two).first)!.teamSize, 2);
      expect(
        RoomMeta.fromJson({'hostUid': 'x', 'status': 'waiting'}).teamSize,
        1,
      );
    });

    test('joiners are auto-assigned to the smaller team, A on a tie → A2 B2; '
        'a 5th person is refused', () async {
      final db = FakeRtdbService();
      final repo = RoomRepository(db);
      final code = await room2v2(db, repo);
      for (final id in ['b', 'c', 'd']) {
        await repo.joinRoom(code, uid: id, name: id.toUpperCase());
      }
      final t = await teams(db, code);
      expect(t, {'h': 'A', 'b': 'B', 'c': 'A', 'd': 'B'});
      await expectLater(
        repo.joinRoom(code, uid: 'e', name: 'E'),
        throwsA(isA<RoomException>()),
      );
    });

    test(
      'someone left: the next joiner fills the team that lost a player',
      () async {
        final db = FakeRtdbService();
        final repo = RoomRepository(db);
        final code = await room2v2(db, repo);
        for (final id in ['b', 'c', 'd']) {
          await repo.joinRoom(code, uid: id, name: id);
        }
        await repo.leave(code, 'd'); // B팀이 1명
        await repo.joinRoom(code, uid: 'e', name: 'E');
        expect((await teams(db, code))['e'], 'B');
      },
    );

    test(
      '1v1 room is unchanged: the joiner goes to B, a 3rd is refused',
      () async {
        final db = FakeRtdbService();
        final repo = RoomRepository(db);
        final code = await repo.createRoom(uid: 'a', name: 'A');
        await repo.joinRoom(code, uid: 'b', name: 'B');
        expect(await teams(db, code), {'a': 'A', 'b': 'B'});
        await expectLater(
          repo.joinRoom(code, uid: 'c', name: 'C'),
          throwsA(isA<RoomException>()),
        );
      },
    );

    test('moveTeam changes only my own team', () async {
      final db = FakeRtdbService();
      final repo = RoomRepository(db);
      final code = await room2v2(db, repo);
      await repo.joinRoom(code, uid: 'b', name: 'B');
      await repo.moveTeam(code, 'h', 'B');
      expect(await teams(db, code), {'h': 'B', 'b': 'B'});
    });

    test('swap writes go to my own player node only', () async {
      final db = FakeRtdbService()..serverTime = 5000;
      final repo = RoomRepository(db);
      final code = await room2v2(db, repo);
      await repo.joinRoom(code, uid: 'b', name: 'B');

      await repo.requestSwap(code, 'h', 'b');
      var h = (await db.get('rooms/$code/players/h'))! as Map;
      expect((h['swapTo'], h['swapAt']), ('b', 5000));
      expect(
        ((await db.get('rooms/$code/players/b'))! as Map)['swapTo'],
        isNull,
      );

      await repo.acceptSwap(code, 'b', requester: 'h', team: 'A');
      final b = (await db.get('rooms/$code/players/b'))! as Map;
      expect((b['team'], b['swapAccepted']), ('A', 'h'));

      await repo.finishSwap(code, 'h', 'B');
      h = (await db.get('rooms/$code/players/h'))! as Map;
      expect((h['team'], h['swapTo'], h['swapAt']), ('B', null, null));

      await repo.clearSwapMarks(code, 'b');
      expect(
        ((await db.get('rooms/$code/players/b'))! as Map)['swapAccepted'],
        isNull,
      );

      await repo.declineSwap(code, 'b', 'h');
      expect(
        ((await db.get('rooms/$code/players/b'))! as Map)['swapDeclined'],
        'h',
      );
      await repo.clearSwapRequest(code, 'h');
    });
  });

  test('leave: the room is deleted when the last player leaves', () async {
    final db = FakeRtdbService();
    final repo = RoomRepository(db);
    final code = await repo.createRoom(uid: 'a', name: 'A');
    await repo.joinRoom(code, uid: 'b', name: 'B');

    await repo.leave(code, 'a');
    expect(await db.get('rooms/$code/players/a/connected'), false);

    await repo.leave(code, 'b');
    expect(await db.get('rooms/$code'), isNull);

    // 나간 뒤 끊겨도 빈 방이 다시 생기지 않는다(onDisconnect 취소).
    db.disconnect();
    expect(await db.get('rooms/$code'), isNull);
  });

  test(
    'leave: no error when the other player deleted the room first',
    () async {
      final db = _RacingDb();
      final repo = RoomRepository(db);
      final code = await repo.createRoom(uid: 'a', name: 'A');
      await repo.joinRoom(code, uid: 'b', name: 'B');
      await db.set('rooms/$code/players/a/connected', false);
      // b가 나가는 중간에 a가 방을 지운다(실제 2026-10-13 실서버에서 겪음).
      db.beforeRemove = (path) async {
        if (path == 'rooms/$code/states/b') await db.remove('rooms/$code');
      };

      await repo.leave(code, 'b');
      expect(await db.get('rooms/$code/players'), isNull);
    },
  );

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

  test('bot room: offline, me (A) and bot (B), already playing', () async {
    final r = await RoomRepository.botRoom(
      uid: 'me',
      name: 'Me',
      durationMs: 1000,
    );
    final players = await r.rooms.players(r.code).first;
    expect(
      {for (final p in players) p.uid: p.team},
      {'me': RoomMeta.teamA, RoomRepository.botUid: RoomMeta.teamB},
    );
    final meta = (await r.rooms.meta(r.code).first)!;
    expect(meta.status, RoomMeta.playing);
    expect(meta.endsAt, greaterThan(0));

    // 변경이 비동기로 전달된다(체력 트랜잭션 → hp 스트림).
    await r.rooms.setHp(
      r.code,
      'me',
      const NetHp(value: 100, protectedUntil: 0),
    );
    final next = r.rooms.hp(r.code).firstWhere((h) => h['me']?.value == 87);
    await r.rooms.damage(r.code, 'me', (cur) => cur.value - 13);
    expect((await next)['me']!.value, 87);
  });
}

/// 실제 DB 규칙처럼 참가자가 없는(이미 지워진) 방을 지우면 거부한다. [beforeRemove]로 끼어들기.
class _RacingDb extends FakeRtdbService {
  Future<void> Function(String path)? beforeRemove;

  @override
  Future<void> remove(String path) async {
    final hook = beforeRemove;
    beforeRemove = null;
    await hook?.call(path);
    final players = await get('$path/players');
    if (RegExp(r'^rooms/[^/]+$').hasMatch(path) &&
        (players is! Map || players.isEmpty)) {
      throw Exception('permission_denied');
    }
    await super.remove(path);
  }
}
