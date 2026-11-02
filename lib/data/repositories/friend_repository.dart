import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../rules/friends.dart';
import '../services/rtdb_service.dart';

final friendRepositoryProvider = Provider(
  (ref) => FriendRepository(FirebaseRtdbService()),
);

typedef FriendInfo = ({String nickname, int level, bool online, int lastSeen});

/// 친구 코드·요청·목록·접속 상태(decisions 18장).
class FriendRepository {
  FriendRepository(this._db, {Random? random}) : _random = random ?? Random();

  final RtdbService _db;
  final Random _random;

  /// 내 친구 코드. 없으면 빈 코드를 트랜잭션으로 선점하고 프로필에도 저장한다.
  Future<String> myCode(String uid) async {
    if (await _db.get('users/$uid/friendCode') case final String code) {
      return code;
    }
    // 32^6 ≈ 10억 개라 겹치는 일은 드물다. 그래도 몇 번은 다시 뽑는다.
    for (var i = 0; i < 10; i++) {
      final code = newFriendCode(_random);
      final r = await _db.transaction(
        'friendCodes/$code',
        (cur) => cur == null || cur == uid ? uid : txAbort,
      );
      if (r.committed && r.value == uid) {
        await _db.set('users/$uid/friendCode', code);
        return code;
      }
    }
    throw StateError('친구 코드를 만들지 못했습니다.');
  }

  Future<String?> uidOf(String code) async =>
      await _db.get('friendCodes/$code') as String?;

  Future<String?> nicknameOf(String uid) async =>
      await _db.get('users/$uid/nickname') as String?;

  Future<void> send({
    required String me,
    required String myName,
    required String to,
    required String toName,
  }) => _db.update('', {
    'friendRequests/$to/$me': {'name': myName, 't': serverTimestamp},
    'users/$me/sentRequests/$to': {'name': toName, 't': serverTimestamp},
  });

  Future<void> accept({required String me, required String from}) =>
      _db.update('', {
        'users/$me/friends/$from': {'since': serverTimestamp},
        'users/$from/friends/$me': {'since': serverTimestamp},
        'friendRequests/$me/$from': null,
      });

  Future<void> reject({required String me, required String from}) =>
      _db.remove('friendRequests/$me/$from');

  Future<void> cancel({required String me, required String to}) => _db.update(
    '',
    {'friendRequests/$to/$me': null, 'users/$me/sentRequests/$to': null},
  );

  /// 상대가 수락·거절해서 요청이 없어진 뒤 내 보낸 요청 색인을 지운다.
  Future<void> forgetSent({required String me, required String to}) =>
      _db.remove('users/$me/sentRequests/$to');

  Future<void> remove({required String me, required String friend}) =>
      _db.update('', {
        'users/$me/friends/$friend': null,
        'users/$friend/friends/$me': null,
      });

  Stream<List<FriendRequest>> received(String uid) =>
      _db.watch('friendRequests/$uid').map(_requests);

  Stream<List<FriendRequest>> sent(String uid) =>
      _db.watch('users/$uid/sentRequests').map(_requests);

  Stream<bool> requestExists({required String to, required String from}) =>
      _db.watch('friendRequests/$to/$from').map((v) => v != null);

  Stream<Set<String>> friends(String uid) => _db
      .watch('users/$uid/friends')
      .map((v) => v is Map ? {for (final k in v.keys) k as String} : {});

  /// 친구 카드. 닉네임·레벨·접속 상태를 모두 한 번씩 읽은 뒤부터 보낸다.
  Stream<FriendInfo> friendInfo(String uid) {
    late StreamController<FriendInfo> c;
    final subs = <StreamSubscription<Object?>>[];
    final v = <String, Object?>{};
    const paths = ['nickname', 'level', 'presence'];
    void got(String key, Object? value) {
      v[key] = value;
      if (v.length < paths.length) return;
      final p = v['presence'] is Map ? v['presence']! as Map : const {};
      c.add((
        nickname: v['nickname'] as String? ?? '',
        level: (v['level'] as num?)?.toInt() ?? 1,
        online: p['online'] == true,
        lastSeen: (p['lastSeen'] as num?)?.toInt() ?? 0,
      ));
    }

    c = StreamController<FriendInfo>(
      onListen: () => subs.addAll([
        for (final key in paths)
          _db
              .watch(key == 'presence' ? 'presence/$uid' : 'users/$uid/$key')
              .listen((value) => got(key, value)),
      ]),
      onCancel: () {
        for (final s in subs) {
          unawaited(s.cancel());
        }
      },
    );
    return c.stream;
  }

  /// DB에 붙을 때마다 online=true, 끊기면 서버가 false·lastSeen을 쓴다.
  StreamSubscription<Object?> keepOnline(String uid) =>
      _db.watch('.info/connected').distinct().listen((c) async {
        if (c != true) return;
        final path = 'presence/$uid';
        await _db.setOnDisconnect(path, {
          'online': false,
          'lastSeen': serverTimestamp,
        });
        await _db.set(path, {'online': true, 'lastSeen': serverTimestamp});
      });

  List<FriendRequest> _requests(Object? v) => [
    if (v is Map)
      for (final e in v.entries)
        if (e.value case {'name': final String name, 't': final num t})
          (uid: e.key as String, name: name, t: t.toInt()),
  ];
}
