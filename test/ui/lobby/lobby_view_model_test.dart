import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/room_repository.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/room_teams.dart';
import 'package:topsoldier/ui/format.dart';
import 'package:topsoldier/ui/lobby/lobby_view_model.dart';

import '../../fakes.dart';

ProviderContainer lobbyFor(String uid, FakeRtdbService db) {
  final c = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        AuthRepository(FakeAuthService(uid)),
      ),
      roomRepositoryProvider.overrideWithValue(
        RoomRepository(db, clock: () => db.serverTime),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('create → waiting room as host, cannot start alone', () async {
    final host = lobbyFor('a', FakeRtdbService());
    await host.read(lobbyProvider.notifier).createRoom();
    await pumpEventQueue();

    final s = host.read(lobbyProvider);
    expect(s.code, matches(RegExp(r'^\d{4}$')));
    expect(s.isHost, true);
    expect(s.players.map((p) => p.uid), ['a']);
    expect(s.canStart, false);
  });

  test('second player joins → host can start → both started', () async {
    final db = FakeRtdbService();
    final host = lobbyFor('a', db);
    final guest = lobbyFor('b', db);
    await host.read(lobbyProvider.notifier).createRoom();
    final code = host.read(lobbyProvider).code!;

    await guest.read(lobbyProvider.notifier).joinRoom(code);
    await pumpEventQueue();

    expect(host.read(lobbyProvider).players.length, 2);
    expect(host.read(lobbyProvider).canStart, true);
    expect(guest.read(lobbyProvider).isHost, false);
    expect(guest.read(lobbyProvider).canStart, false);

    await host.read(lobbyProvider.notifier).start();
    await pumpEventQueue();
    expect(host.read(lobbyProvider).started, true);
    expect(guest.read(lobbyProvider).started, true);
  });

  test(
    'host picks outpost → both clients see outpost; default is duel',
    () async {
      final db = FakeRtdbService();
      final host = lobbyFor('a', db);
      final guest = lobbyFor('b', db);
      expect(host.read(lobbyProvider).map, 'duel');

      host.read(lobbyProvider.notifier).selectMap('outpost');
      await host.read(lobbyProvider.notifier).createRoom();
      await guest
          .read(lobbyProvider.notifier)
          .joinRoom(host.read(lobbyProvider).code!);
      await pumpEventQueue();

      expect(host.read(lobbyProvider).map, 'outpost');
      expect(guest.read(lobbyProvider).map, 'outpost');
    },
  );

  test('room made without picking stays duel for the guest too', () async {
    final db = FakeRtdbService();
    final host = lobbyFor('a', db);
    final guest = lobbyFor('b', db);
    await host.read(lobbyProvider.notifier).createRoom();
    await guest
        .read(lobbyProvider.notifier)
        .joinRoom(host.read(lobbyProvider).code!);
    await pumpEventQueue();

    expect(guest.read(lobbyProvider).map, 'duel');
  });

  test('join with unknown code shows an error and stays in menu', () async {
    final guest = lobbyFor('b', FakeRtdbService());
    await guest.read(lobbyProvider.notifier).joinRoom('4321');

    final s = guest.read(lobbyProvider);
    expect(s.code, isNull);
    expect(s.error, isNotNull);
    expect(s.busy, false);
  });

  test('join with non-4-digit input shows an error', () async {
    final guest = lobbyFor('b', FakeRtdbService());
    await guest.read(lobbyProvider.notifier).joinRoom('12a');
    expect(guest.read(lobbyProvider).error, isNotNull);
  });

  test(
    'a player who leaves the waiting room disappears from the list',
    () async {
      final db = FakeRtdbService();
      final host = lobbyFor('a', db);
      final guest = lobbyFor('b', db);
      await host.read(lobbyProvider.notifier).createRoom();
      await guest
          .read(lobbyProvider.notifier)
          .joinRoom(host.read(lobbyProvider).code!);
      await pumpEventQueue();

      await guest.read(lobbyProvider.notifier).leaveRoom();
      await pumpEventQueue();

      expect(host.read(lobbyProvider).players.map((p) => p.uid), ['a']);
      expect(guest.read(lobbyProvider).code, isNull);
    },
  );

  testWidgets('create room with no DB connection: message, no room', (
    tester,
  ) async {
    final db = FakeRtdbService()..connected = false;
    final host = lobbyFor('a', db);
    final f = host.read(lobbyProvider.notifier).createRoom();
    await tester.pump(connectWait + const Duration(seconds: 1));
    await f;

    final s = host.read(lobbyProvider);
    expect(s.error, connectionErrorText);
    expect(s.busy, false);
    expect(s.code, isNull);
    expect(await db.get('rooms'), anyOf(isNull, isEmpty));
  });

  testWidgets('join with no DB connection: message', (tester) async {
    final db = FakeRtdbService()..connected = false;
    final guest = lobbyFor('b', db);
    final f = guest.read(lobbyProvider.notifier).joinRoom('1234');
    await tester.pump(connectWait + const Duration(seconds: 1));
    await f;
    expect(guest.read(lobbyProvider).error, connectionErrorText);
  });

  testWidgets('create room: the server does not answer → message after 8 s', (
    tester,
  ) async {
    final db = FakeRtdbService();
    db.hold = Completer<void>();
    addTearDown(() => db.hold?.complete());
    final host = lobbyFor('a', db);
    final f = host.read(lobbyProvider.notifier).createRoom();
    await tester.pump(requestTimeout + const Duration(seconds: 1));
    await f;
    expect(host.read(lobbyProvider).error, connectionErrorText);
    expect(host.read(lobbyProvider).busy, false);
  });

  group('2v2 friendly room: teams, moving, swapping (decisions 12장)', () {
    /// 모두의 상태를 갱신하고 자리 바꾸기 차례를 처리한다(1초 타이머가 하는 일).
    Future<void> settle(Map<String, ProviderContainer> all) async {
      for (var i = 0; i < 5; i++) {
        await pumpEventQueue();
        for (final c in all.values) {
          await c.read(lobbyProvider.notifier).tick();
        }
      }
      await pumpEventQueue();
    }

    /// 방장 h + 입장자 b, c, d가 있는 2대2 방. 각자 자기 로비 컨테이너.
    Future<(FakeRtdbService, Map<String, ProviderContainer>)> room2v2({
      List<String> joiners = const ['b', 'c', 'd'],
    }) async {
      final db = FakeRtdbService();
      final all = <String, ProviderContainer>{'h': lobbyFor('h', db)};
      all['h']!.read(lobbyProvider.notifier).selectTeamSize(2);
      await all['h']!.read(lobbyProvider.notifier).createRoom();
      final code = all['h']!.read(lobbyProvider).code!;
      for (final id in joiners) {
        all[id] = lobbyFor(id, db);
        await all[id]!.read(lobbyProvider.notifier).joinRoom(code);
      }
      await settle(all);
      return (db, all);
    }

    LobbyState st(Map<String, ProviderContainer> all, String id) =>
        all[id]!.read(lobbyProvider);

    LobbyViewModel vmOf(Map<String, ProviderContainer> all, String id) =>
        all[id]!.read(lobbyProvider.notifier);

    String teamOf(
      Map<String, ProviderContainer> all,
      String viewer,
      String id,
    ) => st(all, viewer).players.firstWhere((p) => p.uid == id).team;

    test(
      'picking 2v2 locks the map to outpost; the room opens with teamSize 2',
      () async {
        final c = lobbyFor('h', FakeRtdbService());
        final vm = c.read(lobbyProvider.notifier);
        expect(c.read(lobbyProvider).teamSize, 1); // 기본 1대1
        vm.selectTeamSize(2);
        expect(
          (c.read(lobbyProvider).teamSize, c.read(lobbyProvider).map),
          (2, 'outpost'),
        );
        vm.selectMap('duel'); // 2대2에서는 못 바꾼다
        expect(c.read(lobbyProvider).map, 'outpost');
        await vm.createRoom();
        await pumpEventQueue();
        expect(c.read(lobbyProvider).teamSize, 2);
      },
    );

    test('three joiners → A2 B2 for everyone; the host can start (2v2 is open '
        'in stage 2)', () async {
      final (_, all) = await room2v2();
      for (final id in all.keys) {
        final s = st(all, id);
        expect(s.teamSize, 2);
        expect([for (final p in s.teamPlayers('A')) p.uid]..sort(), ['c', 'h']);
        expect([for (final p in s.teamPlayers('B')) p.uid]..sort(), ['b', 'd']);
      }
      expect(st(all, 'h').canStart, true);
      expect(st(all, 'b').canStart, false); // 방장만
      // 시작하면 모두 게임 화면으로, 시작 줄 값(팀 인원·내 순서)도 함께.
      await vmOf(all, 'h').start();
      await settle(all);
      expect(
        [for (final c in all.values) c.read(lobbyProvider).started],
        [true, true, true, true],
      );
      expect(st(all, 'h').teamSize, 2);
      expect(
        [st(all, 'c').allyIndex, st(all, 'h').allyIndex],
        [0, 1],
      ); // uid 순(c < h는 아님)
    });

    test(
      '2v2 cannot start while a team is short or a swap is pending',
      () async {
        final (_, all) = await room2v2(joiners: ['b', 'c']);
        expect(st(all, 'h').canStart, false); // 3명
        final (_, full) = await room2v2();
        await vmOf(full, 'h').requestSwap('b');
        await settle(full);
        expect(st(full, 'h').swapInProgress, true);
        expect(st(full, 'h').canStart, false);
      },
    );

    test('one leaves, the one left behind moves into the empty seat', () async {
      final (_, all) = await room2v2();
      // B팀의 d가 나감 → B1. A팀의 c는 빈자리로 옮길 수 있고, B팀의 b는 A가 꽉 차서 못 옮긴다.
      await vmOf(all, 'd').leaveRoom();
      await settle(all);
      expect(st(all, 'c').canMove, true);
      expect(st(all, 'b').canMove, false);

      await vmOf(all, 'c').moveToOtherTeam();
      await settle(all);
      expect(teamOf(all, 'h', 'c'), 'B');
      expect(st(all, 'c').canMove, true); // A에 빈자리가 생겼으니 다시 옮길 수 있다
    });

    test('swap accepted: the two exchange teams, nothing else moves', () async {
      final (_, all) = await room2v2();
      expect(st(all, 'h').swapBlock('b'), SwapBlock.ok);
      await vmOf(all, 'h').requestSwap('b');
      await settle(all);
      expect(st(all, 'b').incoming?.uid, 'h'); // b에게 요청이 보인다
      expect(st(all, 'h').outgoing?.uid, 'b'); // 요청자는 대기 중
      expect(st(all, 'h').swapInProgress, true);

      await vmOf(all, 'b').acceptSwap();
      await settle(all);
      expect(teamOf(all, 'c', 'h'), 'B');
      expect(teamOf(all, 'c', 'b'), 'A');
      expect(teamOf(all, 'c', 'c'), 'A');
      expect(teamOf(all, 'c', 'd'), 'B');
      expect(st(all, 'h').swapInProgress, false);
      expect(st(all, 'h').incoming, isNull);
      expect(st(all, 'h').outgoing, isNull);
    });

    test(
      'swap declined: nothing changes, the requester gets a notice',
      () async {
        final (_, all) = await room2v2();
        await vmOf(all, 'h').requestSwap('b');
        await settle(all);
        await vmOf(all, 'b').declineSwap();
        await settle(all);
        expect(teamOf(all, 'c', 'h'), 'A');
        expect(teamOf(all, 'c', 'b'), 'B');
        expect(st(all, 'h').notice, contains('거절'));
        expect(st(all, 'h').outgoing, isNull);
        expect(st(all, 'h').swapInProgress, false);
      },
    );

    test('no answer for 10 s: the request cancels itself', () async {
      final (db, all) = await room2v2();
      await vmOf(all, 'h').requestSwap('b');
      await settle(all);
      expect(st(all, 'b').incoming, isNotNull);

      db.serverTime += swapTimeoutMs; // 10초 경과
      await settle(all);
      expect(st(all, 'b').incoming, isNull); // 창이 닫힌다
      expect(st(all, 'h').outgoing, isNull);
      expect(st(all, 'h').notice, contains('응답이 없어'));
      expect(teamOf(all, 'c', 'h'), 'A');
      expect(teamOf(all, 'c', 'b'), 'B');
    });

    test('the requester can cancel', () async {
      final (_, all) = await room2v2();
      await vmOf(all, 'h').requestSwap('b');
      await settle(all);
      await vmOf(all, 'h').cancelSwap();
      await settle(all);
      expect(st(all, 'b').incoming, isNull);
      expect(st(all, 'h').outgoing, isNull);
      expect(st(all, 'h').swapBlock('b'), SwapBlock.ok); // 다시 요청할 수 있다
    });

    test(
      'one request at a time: a busy player and a busy target are blocked',
      () async {
        final (_, all) = await room2v2();
        await vmOf(all, 'h').requestSwap('b');
        await settle(all);
        expect(st(all, 'h').swapBlock('d'), SwapBlock.iAmBusy);
        expect(st(all, 'c').swapBlock('b'), SwapBlock.targetBusy);
        // 요청을 받은 b도 응답이 먼저라 새로 요청은 못 한다.
        expect(st(all, 'b').swapBlock('c'), SwapBlock.iAmBusy);
      },
    );

    test(
      '1v1 room: start works as before, 2v2 never starts in stage 1',
      () async {
        final db = FakeRtdbService();
        final host = lobbyFor('a', db);
        final guest = lobbyFor('b', db);
        await host.read(lobbyProvider.notifier).createRoom();
        await guest
            .read(lobbyProvider.notifier)
            .joinRoom(host.read(lobbyProvider).code!);
        await pumpEventQueue();
        expect(host.read(lobbyProvider).teamSize, 1);
        expect(host.read(lobbyProvider).canStart, true);
        await host.read(lobbyProvider.notifier).start();
        await pumpEventQueue();
        expect(guest.read(lobbyProvider).started, true);
      },
    );
  });
}
