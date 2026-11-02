import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/repositories/friend_repository.dart';
import 'package:topsoldier/data/repositories/profile_repository.dart';
import 'package:topsoldier/ui/friends/friends_view_model.dart';

import '../../fakes.dart';

void main() {
  late FakeRtdbService db;

  /// [uid]로 로그인한 기기 하나(같은 가짜 DB를 쓴다).
  ProviderContainer device(String uid) {
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          AuthRepository(FakeAuthService(uid)),
        ),
        friendRepositoryProvider.overrideWithValue(FriendRepository(db)),
        profileRepositoryProvider.overrideWithValue(ProfileRepository(db)),
      ],
    );
    addTearDown(c.dispose);
    c.listen(friendsProvider, (_, _) {});
    return c;
  }

  setUp(() async {
    db = FakeRtdbService();
    await db.set('users/a', {'nickname': 'Alice', 'level': 1});
    await db.set('users/b', {'nickname': 'Bob', 'level': 2});
  });

  Future<String> codeOf(ProviderContainer c) async {
    for (var i = 0; i < 20 && c.read(friendsProvider).code == null; i++) {
      await pumpEventQueue();
    }
    return c.read(friendsProvider).code!;
  }

  test('anonymous account shows the Google hint', () async {
    final a = device('a');
    await codeOf(a);
    expect(a.read(friendsProvider).anonymous, isTrue);
  });

  test('A sends to B → B accepts → both friends, lists clean', () async {
    final a = device('a'), b = device('b');
    final bCode = await codeOf(b);
    await codeOf(a);

    final r = await a.read(friendsProvider.notifier).send(bCode.toLowerCase());
    expect(r.message, '요청을 보냈습니다');
    expect(b.read(friendsProvider).received.single.name, 'Alice');
    expect(a.read(friendsProvider).sent.single.name, 'Bob');

    expect(await b.read(friendsProvider.notifier).accept('a'), isNull);
    await pumpEventQueue();
    expect(a.read(friendsProvider).friends, {'b'});
    expect(b.read(friendsProvider).friends, {'a'});
    expect(b.read(friendsProvider).received, isEmpty);
    expect(a.read(friendsProvider).sent, isEmpty);
  });

  test(
    'blocked sends: bad format, unknown, own code, again, reverse',
    () async {
      final a = device('a'), b = device('b');
      final aCode = await codeOf(a), bCode = await codeOf(b);
      final vm = a.read(friendsProvider.notifier);

      expect((await vm.send('nope')).message, startsWith('친구 코드 형식'));
      expect((await vm.send('TS-ZZZZZZ')).message, '없는 친구 코드입니다');
      expect((await vm.send(aCode)).message, '내 친구 코드입니다');
      await vm.send(bCode);
      expect((await vm.send(bCode)).message, '이미 요청을 보냈습니다');

      final back = await b.read(friendsProvider.notifier).send(aCode);
      expect(back, (message: '상대가 이미 요청을 보냈습니다', acceptFrom: 'a'));
    },
  );

  test(
    'reject and cancel clear both sides; remove clears both lists',
    () async {
      final a = device('a'), b = device('b');
      final bCode = await codeOf(b);
      await codeOf(a);
      final av = a.read(friendsProvider.notifier);
      final bv = b.read(friendsProvider.notifier);

      await av.send(bCode);
      await bv.reject('a');
      await pumpEventQueue();
      expect(a.read(friendsProvider).sent, isEmpty);

      await av.send(bCode);
      await av.cancel('b');
      await pumpEventQueue();
      expect(b.read(friendsProvider).received, isEmpty);

      await av.send(bCode);
      await bv.accept('a');
      await av.remove('b');
      await pumpEventQueue();
      expect(a.read(friendsProvider).friends, isEmpty);
      expect(b.read(friendsProvider).friends, isEmpty);
    },
  );
}
