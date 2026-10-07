import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/room_repository.dart';
import 'package:topsoldier/ui/lobby/lobby_view_model.dart';

import '../../fakes.dart';

ProviderContainer lobbyFor(String uid, FakeRtdbService db) {
  final c = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        AuthRepository(FakeAuthService(uid)),
      ),
      roomRepositoryProvider.overrideWithValue(RoomRepository(db)),
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
}
