import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/friends.dart';

void main() {
  group('friend code', () {
    test('TS- + 6 chars, never 0 O 1 I', () {
      final r = Random(1);
      for (var i = 0; i < 2000; i++) {
        final c = newFriendCode(r);
        expect(c, matches(RegExp(r'^TS-[A-HJ-NP-Z2-9]{6}$')));
        expect(c.substring(3), isNot(matches(RegExp('[0O1I]'))));
      }
    });

    test('alphabet is 32 chars without 0 O 1 I', () {
      expect(friendCodeChars.length, 32);
      expect(friendCodeChars.split('').toSet().length, 32);
      for (final bad in ['0', 'O', '1', 'I']) {
        expect(friendCodeChars.contains(bad), isFalse);
      }
    });

    test('input: trims, uppercases, TS- optional', () {
      expect(normalizeFriendCode(' ts-abc234 '), 'TS-ABC234');
      expect(normalizeFriendCode('abc234'), 'TS-ABC234');
      expect(normalizeFriendCode('TS-ABC234'), 'TS-ABC234');
    });

    test('input: wrong length or excluded chars → null', () {
      expect(normalizeFriendCode(''), isNull);
      expect(normalizeFriendCode('TS-ABC23'), isNull);
      expect(normalizeFriendCode('TS-ABC2345'), isNull);
      expect(normalizeFriendCode('TS-ABC0O1'), isNull);
      expect(normalizeFriendCode('TS-ABCI23'), isNull);
      expect(normalizeFriendCode('XX-ABC234'), isNull);
    });
  });

  group('can I send a request', () {
    FriendRequestBlock? block({
      String? target = 'b',
      Set<String> friends = const {},
      Set<String> sent = const {},
      Set<String> received = const {},
    }) => requestBlock(
      me: 'a',
      target: target,
      friends: friends,
      sent: sent,
      received: received,
    );

    test('ok', () => expect(block(), isNull));
    test('unknown code', () {
      expect(block(target: null), FriendRequestBlock.invalidCode);
    });
    test('my own code', () {
      expect(block(target: 'a'), FriendRequestBlock.self);
    });
    test('already friends', () {
      expect(block(friends: {'b'}), FriendRequestBlock.alreadyFriend);
    });
    test('already sent', () {
      expect(block(sent: {'b'}), FriendRequestBlock.alreadySent);
    });
    test('they already asked me → accept instead', () {
      expect(block(received: {'b'}), FriendRequestBlock.theyAsked);
    });
    test('friend list full', () {
      final full = {for (var i = 0; i < friendMax; i++) 'f$i'};
      expect(block(friends: full), FriendRequestBlock.tooManyFriends);
      expect(block(friends: full.skip(1).toSet()), isNull);
    });
  });

  test('accept only while under the friend limit', () {
    expect(canAcceptFriend(friendMax - 1), isTrue);
    expect(canAcceptFriend(friendMax), isFalse);
  });

  test('received requests: oldest first, at most the limit', () {
    final reqs = [
      for (var i = 0; i < friendRequestMax + 5; i++)
        (uid: 'u$i', name: 'n', t: 100 - i),
    ];
    final shown = visibleRequests(reqs);
    expect(shown.length, friendRequestMax);
    expect(shown.first.t, 100 - (friendRequestMax + 4));
    for (var i = 1; i < shown.length; i++) {
      expect(shown[i].t, greaterThanOrEqualTo(shown[i - 1].t));
    }
  });

  group('status flow', () {
    FriendStatus status({
      Set<String> friends = const {},
      Set<String> sent = const {},
      Set<String> received = const {},
    }) => friendStatus('b', friends: friends, sent: sent, received: received);

    test('none → sent → (accepted) friend', () {
      expect(status(), FriendStatus.none);
      expect(status(sent: {'b'}), FriendStatus.sent);
      expect(status(friends: {'b'}), FriendStatus.friend);
    });
    test('received → rejected/cancelled → none', () {
      expect(status(received: {'b'}), FriendStatus.received);
      expect(status(), FriendStatus.none);
    });
    test('friend wins over a leftover request', () {
      expect(status(friends: {'b'}, sent: {'b'}), FriendStatus.friend);
    });
  });

  group('last seen', () {
    const now = 1000000000;
    test(
      'under a minute',
      () => expect(lastSeenText(now, now - 59000), '방금 전'),
    );
    test('minutes', () => expect(lastSeenText(now, now - 5 * 60000), '5분 전'));
    test('hours', () => expect(lastSeenText(now, now - 3 * 3600000), '3시간 전'));
    test('days', () => expect(lastSeenText(now, now - 2 * 86400000), '2일 전'));
    test('clock skew (future) → just now', () {
      expect(lastSeenText(now, now + 5000), '방금 전');
    });
  });
}
