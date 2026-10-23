import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/repositories/friend_repository.dart';

import '../../fakes.dart';

void main() {
  late FakeRtdbService db;
  late FriendRepository repo;

  setUp(() {
    db = FakeRtdbService();
    repo = FriendRepository(db, random: Random(1));
  });

  group('my code', () {
    test('first time: claims a code and saves it on the profile', () async {
      final code = await repo.myCode('a');
      expect(code, startsWith('TS-'));
      expect(db.root['friendCodes'], {code: 'a'});
      expect(await db.get('users/a/friendCode'), code);
    });

    test('second time: same code, no new claim', () async {
      final code = await repo.myCode('a');
      expect(await repo.myCode('a'), code);
      expect((db.root['friendCodes']! as Map).length, 1);
    });

    test('taken code → tries another', () async {
      final taken = await FriendRepository(db, random: Random(7)).myCode('x');
      final mine = await FriendRepository(db, random: Random(7)).myCode('a');
      expect(mine, isNot(taken));
      expect(db.root['friendCodes'], {taken: 'x', mine: 'a'});
    });

    test('code → uid', () async {
      final code = await repo.myCode('a');
      expect(await repo.uidOf(code), 'a');
      expect(await repo.uidOf('TS-ZZZZZZ'), isNull);
    });
  });

  group('requests', () {
    test('send → shows in their inbox and my sent list', () async {
      await repo.send(me: 'a', myName: 'Alice', to: 'b', toName: 'Bob');
      expect(db.root['friendRequests'], {
        'b': {
          'a': {'name': 'Alice', 't': 1000},
        },
      });
      expect(await db.get('users/a/sentRequests/b'), {
        'name': 'Bob',
        't': 1000,
      });
    });

    test('accept → both friend lists, request gone', () async {
      await repo.send(me: 'a', myName: 'Alice', to: 'b', toName: 'Bob');
      await repo.accept(me: 'b', from: 'a');
      expect(await db.get('users/a/friends/b'), {'since': 1000});
      expect(await db.get('users/b/friends/a'), {'since': 1000});
      expect(await db.get('friendRequests/b/a'), isNull);
    });

    test('reject → request gone, no friends', () async {
      await repo.send(me: 'a', myName: 'Alice', to: 'b', toName: 'Bob');
      await repo.reject(me: 'b', from: 'a');
      expect(await db.get('friendRequests/b/a'), isNull);
      expect(await db.get('users/b/friends'), isNull);
    });

    test('cancel → request and my sent entry gone', () async {
      await repo.send(me: 'a', myName: 'Alice', to: 'b', toName: 'Bob');
      await repo.cancel(me: 'a', to: 'b');
      expect(await db.get('friendRequests/b/a'), isNull);
      expect(await db.get('users/a/sentRequests/b'), isNull);
    });

    test('remove friend → gone on both sides', () async {
      await repo.send(me: 'a', myName: 'Alice', to: 'b', toName: 'Bob');
      await repo.accept(me: 'b', from: 'a');
      await repo.remove(me: 'a', friend: 'b');
      expect(await repo.friends('a').first, isEmpty);
      expect(await repo.friends('b').first, isEmpty);
    });

    test('streams', () async {
      await repo.send(me: 'a', myName: 'Alice', to: 'b', toName: 'Bob');
      expect(await repo.received('b').first, [
        (uid: 'a', name: 'Alice', t: 1000),
      ]);
      expect(await repo.sent('a').first, [(uid: 'b', name: 'Bob', t: 1000)]);
      expect(await repo.requestExists(to: 'b', from: 'a').first, isTrue);
      await repo.accept(me: 'b', from: 'a');
      expect(await repo.friends('a').first, {'b'});
      expect(await repo.requestExists(to: 'b', from: 'a').first, isFalse);
    });
  });

  group('presence', () {
    test(
      'online while connected, offline + lastSeen after disconnect',
      () async {
        final sub = repo.keepOnline('a');
        await pumpEventQueue();
        expect(await db.get('presence/a'), {'online': true, 'lastSeen': 1000});
        db.serverTime = 5000;
        db.disconnect();
        expect(await db.get('presence/a'), {'online': false, 'lastSeen': 5000});
        await sub.cancel();
      },
    );

    test('friend card: nickname, level, presence', () async {
      await db.set('users/b', {'nickname': 'Bob', 'level': 3, 'gold': 9});
      await db.set('presence/b', {'online': true, 'lastSeen': 10});
      expect(await repo.friendInfo('b').first, (
        nickname: 'Bob',
        level: 3,
        online: true,
        lastSeen: 10,
      ));
    });
  });
}
