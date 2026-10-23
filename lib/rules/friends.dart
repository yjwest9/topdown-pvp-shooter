import 'dart:math';

import 'balance.dart';

/// 친구 코드 글자(decisions 18장): 대문자·숫자에서 헷갈리는 0 O 1 I를 뺀 32개.
const friendCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

const _prefix = 'TS-';
const _codeLength = 6;

String newFriendCode(Random random) =>
    _prefix +
    String.fromCharCodes([
      for (var i = 0; i < _codeLength; i++)
        friendCodeChars.codeUnitAt(random.nextInt(friendCodeChars.length)),
    ]);

/// 입력한 코드를 `TS-XXXXXX`로 맞춘다(공백·소문자·`TS-` 생략 허용). 형식이 틀리면 null.
String? normalizeFriendCode(String input) {
  var s = input.trim().toUpperCase();
  if (s.startsWith(_prefix)) s = s.substring(_prefix.length);
  if (s.length != _codeLength) return null;
  if (s.split('').any((c) => !friendCodeChars.contains(c))) return null;
  return _prefix + s;
}

enum FriendRequestBlock {
  invalidCode,
  self,
  alreadyFriend,

  /// 상대가 이미 나에게 보냈다 → 수락으로 안내.
  theyAsked,
  alreadySent,
  tooManyFriends,
}

/// [target](코드로 찾은 uid, 없으면 null)에게 요청을 보낼 수 없는 이유. 보낼 수 있으면 null.
FriendRequestBlock? requestBlock({
  required String me,
  required String? target,
  required Set<String> friends,
  required Set<String> sent,
  required Set<String> received,
}) {
  if (target == null) return FriendRequestBlock.invalidCode;
  if (target == me) return FriendRequestBlock.self;
  if (friends.contains(target)) return FriendRequestBlock.alreadyFriend;
  if (received.contains(target)) return FriendRequestBlock.theyAsked;
  if (sent.contains(target)) return FriendRequestBlock.alreadySent;
  return canAcceptFriend(friends.length)
      ? null
      : FriendRequestBlock.tooManyFriends;
}

bool canAcceptFriend(int friendCount) => friendCount < friendMax;

/// 친구 요청 한 건: 보낸(또는 받는) 사람 uid, 닉네임, 서버 시간.
typedef FriendRequest = ({String uid, String name, int t});

/// 받은 요청은 오래된 순으로 [friendRequestMax]개만 보인다(상한은 받는 쪽에서 지킨다).
List<FriendRequest> visibleRequests(Iterable<FriendRequest> requests) =>
    (requests.toList()..sort((a, b) => a.t.compareTo(b.t)))
        .take(friendRequestMax)
        .toList();

enum FriendStatus { none, sent, received, friend }

FriendStatus friendStatus(
  String uid, {
  required Set<String> friends,
  required Set<String> sent,
  required Set<String> received,
}) {
  if (friends.contains(uid)) return FriendStatus.friend;
  if (received.contains(uid)) return FriendStatus.received;
  if (sent.contains(uid)) return FriendStatus.sent;
  return FriendStatus.none;
}

/// 마지막 접속 표시. 시계가 어긋나 미래면 "방금 전".
String lastSeenText(int now, int lastSeen) {
  final m = (now - lastSeen) ~/ 60000;
  if (m < 1) return '방금 전';
  if (m < 60) return '$m분 전';
  if (m < 60 * 24) return '${m ~/ 60}시간 전';
  return '${m ~/ (60 * 24)}일 전';
}
