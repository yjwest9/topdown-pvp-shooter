import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/friend_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../rules/balance.dart';
import '../../rules/friends.dart';
import '../format.dart';

class FriendsState {
  const FriendsState({
    this.code,
    this.anonymous = true,
    this.received = const [],
    this.sent = const [],
    this.friends = const {},
  });

  /// 내 친구 코드. 아직 못 만들었으면 null.
  final String? code;

  /// 익명 계정이면 "구글 계정을 연결하면…" 한 줄.
  final bool anonymous;

  /// 오래된 순, 최대 [friendRequestMax]개.
  final List<FriendRequest> received;
  final List<FriendRequest> sent;
  final Set<String> friends;

  FriendsState copyWith({
    String? code,
    List<FriendRequest>? received,
    List<FriendRequest>? sent,
    Set<String>? friends,
  }) => FriendsState(
    code: code ?? this.code,
    anonymous: anonymous,
    received: received ?? this.received,
    sent: sent ?? this.sent,
    friends: friends ?? this.friends,
  );
}

/// 친구 카드(닉네임·레벨·접속 상태).
final friendInfoProvider = StreamProvider.autoDispose
    .family<FriendInfo, String>(
      (ref, uid) => ref.read(friendRepositoryProvider).friendInfo(uid),
    );

final friendsProvider =
    NotifierProvider.autoDispose<FriendsViewModel, FriendsState>(
      FriendsViewModel.new,
    );

/// 코드 입력으로 요청을 보낸 결과. [acceptFrom]이 있으면 상대가 이미 보냈다 → 수락 안내.
typedef SendResult = ({String message, String? acceptFrom});

class FriendsViewModel extends Notifier<FriendsState> {
  FriendRepository get _repo => ref.read(friendRepositoryProvider);
  AuthRepository get _auth => ref.read(authRepositoryProvider);

  /// 받은 요청 전체(화면에는 [FriendsState.received]만큼).
  var _allReceived = <FriendRequest>[];

  @override
  FriendsState build() {
    final subs = <StreamSubscription<Object?>>[];
    final watchingSent = <String, StreamSubscription<bool>>{};
    ref.onDispose(() {
      for (final s in [...subs, ...watchingSent.values]) {
        unawaited(s.cancel());
      }
    });
    Future.microtask(() async {
      try {
        final me = await _auth.signIn();
        subs.addAll([
          _repo.received(me).listen((r) {
            _allReceived = r;
            state = state.copyWith(received: visibleRequests(r));
          }),
          _repo.friends(me).listen((f) => state = state.copyWith(friends: f)),
          _repo.sent(me).listen((sent) {
            state = state.copyWith(sent: sent);
            // 상대가 수락·거절해서 요청이 없어지면 내 색인도 지운다.
            for (final r in sent) {
              watchingSent[r.uid] ??= _repo
                  .requestExists(to: r.uid, from: me)
                  .listen((exists) {
                    if (!exists) {
                      unawaited(watchingSent.remove(r.uid)?.cancel());
                      // 알림 도중에 쓰지 않게 한 박자 뒤에.
                      unawaited(
                        Future.microtask(
                          () => _repo.forgetSent(me: me, to: r.uid),
                        ),
                      );
                    }
                  });
            }
          }),
        ]);
        state = state.copyWith(code: await _repo.myCode(me));
      } catch (e) {
        debugPrint('친구 화면 불러오기 실패: $e');
      }
    });
    return FriendsState(anonymous: _auth.googleEmail == null);
  }

  Future<SendResult> send(String input) async {
    final code = normalizeFriendCode(input);
    if (code == null) {
      return (message: '친구 코드 형식이 맞지 않습니다 (예: TS-ABC234)', acceptFrom: null);
    }
    try {
      final me = await _auth.signIn();
      final target = await _repo.uidOf(code);
      final block = requestBlock(
        me: me,
        target: target,
        friends: state.friends,
        sent: {for (final r in state.sent) r.uid},
        received: {for (final r in _allReceived) r.uid},
      );
      if (block != null) {
        return (
          message: switch (block) {
            FriendRequestBlock.invalidCode => '없는 친구 코드입니다',
            FriendRequestBlock.self => '내 친구 코드입니다',
            FriendRequestBlock.alreadyFriend => '이미 친구입니다',
            FriendRequestBlock.theyAsked => '상대가 이미 요청을 보냈습니다',
            FriendRequestBlock.alreadySent => '이미 요청을 보냈습니다',
            FriendRequestBlock.tooManyFriends => '친구는 최대 $friendMax명까지입니다',
          },
          acceptFrom: block == FriendRequestBlock.theyAsked ? target : null,
        );
      }
      await _repo.send(
        me: me,
        myName: await _repo.nicknameOf(me) ?? myNickname(ref),
        to: target!,
        toName: await _repo.nicknameOf(target) ?? code,
      );
      return (message: '요청을 보냈습니다', acceptFrom: null);
    } catch (e) {
      debugPrint('친구 요청 실패: $e');
      return (message: connectionErrorText, acceptFrom: null);
    }
  }

  /// 안 되면 이유.
  Future<String?> accept(String from) async {
    if (!canAcceptFriend(state.friends.length)) {
      return '친구는 최대 $friendMax명까지입니다';
    }
    return _run(() async => _repo.accept(me: await _auth.signIn(), from: from));
  }

  Future<String?> reject(String from) =>
      _run(() async => _repo.reject(me: await _auth.signIn(), from: from));

  Future<String?> cancel(String to) =>
      _run(() async => _repo.cancel(me: await _auth.signIn(), to: to));

  Future<String?> remove(String friend) =>
      _run(() async => _repo.remove(me: await _auth.signIn(), friend: friend));

  Future<String?> _run(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } catch (e) {
      debugPrint('친구 작업 실패: $e');
      return connectionErrorText;
    }
  }
}
