import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/room.dart';
import '../services/rtdb_service.dart';

final roomRepositoryProvider = Provider(
  (ref) => RoomRepository(FirebaseRtdbService()),
);

class RoomException implements Exception {
  const RoomException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 4자리 숫자 방 코드(0000~9999).
String newRoomCode(Random random) =>
    random.nextInt(10000).toString().padLeft(4, '0');

/// 1대1 방. 코드는 처음부터 N명 구조(players·states가 uid 맵).
class RoomRepository {
  RoomRepository(this._db, {Random? random}) : _random = random ?? Random();

  final RtdbService _db;
  final Random _random;

  static const maxPlayers = 2;
  static const _createTries = 20;

  String _room(String code) => 'rooms/$code';

  /// 빈 코드를 찾아 방을 만들고 방장으로 들어간다. 코드 충돌은 meta 생성 트랜잭션으로 막는다.
  Future<String> createRoom({required String uid, required String name}) async {
    for (var i = 0; i < _createTries; i++) {
      final code = newRoomCode(_random);
      final created = await _db.setIfAbsent('${_room(code)}/meta', {
        'hostUid': uid,
        'status': RoomMeta.waiting,
        'mode': 'pvp1v1',
        'map': 'test',
      });
      if (!created) continue;
      await _db.update('${_room(code)}/meta', {'createdAt': serverTimestamp});
      await _enter(code, uid: uid, name: name);
      return code;
    }
    throw const RoomException('방을 만들지 못했습니다. 다시 시도해 주세요.');
  }

  Future<void> joinRoom(
    String code, {
    required String uid,
    required String name,
  }) async {
    final meta = await _db.get('${_room(code)}/meta');
    if (meta == null) throw const RoomException('없는 방 코드입니다.');
    if (RoomMeta.fromJson(meta).status != RoomMeta.waiting) {
      throw const RoomException('이미 시작한 방입니다.');
    }
    final others = _players(await _db.get('${_room(code)}/players'))
        .where((p) => p.connected && p.uid != uid);
    if (others.length >= maxPlayers) {
      throw const RoomException('방이 가득 찼습니다.');
    }
    await _enter(code, uid: uid, name: name);
  }

  Future<void> _enter(
    String code, {
    required String uid,
    required String name,
  }) async {
    final room = _room(code);
    await _db.setOnDisconnect('$room/players/$uid/connected', false);
    await _db.removeOnDisconnect('$room/states/$uid');
    await _db.set('$room/players/$uid', {'name': name, 'connected': true});
  }

  /// 방장만. 둘 다 meta를 보고 게임 화면으로 간다.
  Future<void> start(String code) =>
      _db.update('${_room(code)}/meta', {'status': RoomMeta.playing});

  Future<void> leave(String code, String uid) async {
    await _db.set('${_room(code)}/players/$uid/connected', false);
    await _db.remove('${_room(code)}/states/$uid');
  }

  Stream<RoomMeta?> meta(String code) => _db
      .watch('${_room(code)}/meta')
      .map((v) => v == null ? null : RoomMeta.fromJson(v));

  Stream<List<RoomPlayer>> players(String code) =>
      _db.watch('${_room(code)}/players').map(_players);

  List<RoomPlayer> _players(Object? v) => [
    for (final e in ((v as Map<Object?, Object?>?) ?? const {}).entries)
      RoomPlayer.fromJson(e.key! as String, e.value),
  ];

  // ---------------------------------------------------------- 게임 중

  Future<void> sendState(String code, String uid, NetState s) => _db.set(
    '${_room(code)}/states/$uid',
    {...s.toJson(), 't': serverTimestamp},
  );

  /// uid → 상태. 누가 쓰든 전체가 온다.
  Stream<Map<String, NetState>> states(String code) =>
      _db.watch('${_room(code)}/states').map((v) {
        final m = (v as Map<Object?, Object?>?) ?? const {};
        return {
          for (final e in m.entries)
            e.key! as String: NetState.fromJson(e.value),
        };
      });

  Future<void> sendShot(String code, NetShot s) =>
      _db.push('${_room(code)}/shots', {...s.toJson(), 't': serverTimestamp});

  Stream<NetShot> shots(String code) =>
      _db.childAdded('${_room(code)}/shots').map(NetShot.fromJson);

  /// 서버 시간 − 내 시계(ms).
  Stream<int> serverTimeOffset() =>
      _db.watch('.info/serverTimeOffset').map((v) => (v as num?)?.toInt() ?? 0);
}
