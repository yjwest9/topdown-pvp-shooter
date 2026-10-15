import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/room.dart';
import '../services/local_rtdb_service.dart';
import '../services/rtdb_service.dart';
import 'connection_repository.dart';

final roomRepositoryProvider = Provider(
  (ref) => RoomRepository(FirebaseRtdbService()),
);

/// 방에 들어갈 때 기록하는 내 장착 캐릭터(decisions 13장).
typedef PlayerCharacter = ({String id, int level});

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

  /// 이 저장소가 쓰는 DB의 연결 상태·재연결.
  late final connection = ConnectionRepository(_db);

  static const maxPlayers = 2;

  /// 봇전의 봇 uid.
  static const botUid = 'bot';

  /// 봇전(decisions 12장): 기기 안 메모리 DB에 방을 만들고 나(A)와 봇(B)을 넣어 바로 시작한다.
  static Future<({RoomRepository rooms, String code})> botRoom({
    required String uid,
    required String name,
    required int durationMs,
    PlayerCharacter? character,
  }) async {
    final rooms = RoomRepository(LocalRtdbService());
    final code = await rooms.createRoom(
      uid: uid,
      name: name,
      character: character,
    );
    await rooms.joinRoom(code, uid: botUid, name: 'BOT');
    await rooms.start(code, durationMs: durationMs);
    return (rooms: rooms, code: code);
  }

  static const _createTries = 20;

  String _room(String code) => 'rooms/$code';

  /// 빈 코드를 찾아 방을 만들고 방장으로 들어간다. 코드 충돌은 meta 생성 트랜잭션으로 막는다.
  Future<String> createRoom({
    required String uid,
    required String name,
    PlayerCharacter? character,
  }) async {
    for (var i = 0; i < _createTries; i++) {
      final code = newRoomCode(_random);
      final created = await _db.transaction(
        '${_room(code)}/meta',
        (current) => current != null ? txAbort : _newMeta(uid),
      );
      if (!created.committed) continue;
      await _db.update('${_room(code)}/meta', {'createdAt': serverTimestamp});
      await _enter(
        code,
        uid: uid,
        name: name,
        team: RoomMeta.teamA,
        character: character,
      );
      return code;
    }
    throw const RoomException('방을 만들지 못했습니다. 다시 시도해 주세요.');
  }

  Map<String, Object?> _newMeta(String uid) => {
    'hostUid': uid,
    'status': RoomMeta.waiting,
    'mode': 'pvp1v1',
    'map': 'duel',
  };

  Future<void> joinRoom(
    String code, {
    required String uid,
    required String name,
    PlayerCharacter? character,
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
    await _enter(
      code,
      uid: uid,
      name: name,
      team: RoomMeta.teamB,
      character: character,
    );
  }

  Future<void> _enter(
    String code, {
    required String uid,
    required String name,
    required String team,
    PlayerCharacter? character,
  }) async {
    await _armDisconnect(code, uid);
    await _db.set('${_room(code)}/players/$uid', {
      'name': name,
      'connected': true,
      'team': team,
      if (character != null) ...{
        'character': character.id,
        'characterLevel': character.level,
      },
    });
  }

  Future<void> _armDisconnect(String code, String uid) async {
    final room = _room(code);
    await _db.setOnDisconnect('$room/players/$uid/connected', false);
    await _db.removeOnDisconnect('$room/states/$uid');
  }

  /// 방장만. 둘 다 meta를 보고 게임 화면으로 간다. 시각은 서버 시간 추정값.
  Future<void> start(String code, {required int durationMs}) async {
    final now = await serverNow();
    await _db.update('${_room(code)}/meta', {
      'status': RoomMeta.playing,
      'startedAt': now,
      'endsAt': now + durationMs,
    });
  }

  /// 방장만. [winner]는 [RoomMeta.teamA], [RoomMeta.teamB], [RoomMeta.draw].
  Future<void> endMatch(String code, String winner) => _db.update(
    '${_room(code)}/meta',
    {'status': RoomMeta.ended, 'winner': winner},
  );

  /// 나간다. 마지막 사람이면 방 전체를 지운다(decisions 13장). 내 onDisconnect도 취소한다
  /// (안 하면 나중에 끊길 때 `connected=false`를 써서 빈 방이 다시 생긴다).
  Future<void> leave(String code, String uid) async {
    final room = _room(code);
    await _db.cancelOnDisconnect(room);
    await _db.set('$room/players/$uid/connected', false);
    await _db.remove('$room/states/$uid');
    // ponytail: 둘 다 앱이 꺼지면 방이 남는다.
    final players = _players(await _db.get('$room/players'));
    if (players.any((p) => p.connected)) return;
    try {
      await _db.remove(room);
    } catch (_) {
      // 상대가 먼저 지웠으면 규칙이 거부한다(참가자가 없는 방). 이미 지워졌으니 그대로.
    }
  }

  // ---------------------------------------------------------- 빠른 매칭 (13장)

  static const _slot = 'matchmaking/1v1/waiting';

  /// 빠른 매칭용 방. 4자리 코드 대신 push 키가 방 ID. 나는 방장(A팀).
  /// 매칭 전에 앱이 꺼지면 방이 지워진다([keepRoom]으로 취소).
  Future<String> createQuickRoom({
    required String uid,
    required String name,
    PlayerCharacter? character,
  }) async {
    final id = _db.newKey('rooms');
    await _db.set('${_room(id)}/meta', {
      ..._newMeta(uid),
      'createdAt': serverTimestamp,
    });
    await _enter(
      id,
      uid: uid,
      name: name,
      team: RoomMeta.teamA,
      character: character,
    );
    await _db.removeOnDisconnect(_room(id));
    return id;
  }

  /// 매칭됨: 끊겨도 방을 지우지 않는다(나만 `connected=false`).
  Future<void> keepRoom(String code, String uid) async {
    await _db.cancelOnDisconnect(_room(code));
    await _armDisconnect(code, uid);
  }

  /// 매칭 전 취소: 방 전체를 지운다.
  Future<void> deleteRoom(String code) async {
    await _db.cancelOnDisconnect(_room(code));
    await _db.remove(_room(code));
  }

  /// 대기석 트랜잭션. [next]가 지금 자리로 새 자리를 정한다(null이면 그대로 둠).
  /// 서버 값이 바뀌어 있으면 다시 부른다. 끝났을 때 자리를 돌려준다.
  Future<WaitingSlot?> claimSlot(
    WaitingSlot? Function(WaitingSlot? current) next,
  ) async {
    final r = await _db.transaction(
      _slot,
      (cur) =>
          next(cur == null ? null : WaitingSlot.fromJson(cur))?.toJson() ??
          txAbort,
    );
    return r.value == null ? null : WaitingSlot.fromJson(r.value);
  }

  /// 앉은 뒤: 앱이 꺼지면 내 자리를 지운다(DB 규칙상 내 자리일 때만 지워진다).
  Future<void> removeSlotOnDisconnect() => _db.removeOnDisconnect(_slot);

  /// 아직 내 자리이고 아무도 안 잡았으면 t를 갱신(살아 있다는 표시).
  Future<void> heartbeat(String uid, int serverNow) =>
      _db.transaction(_slot, (cur) {
        if (cur == null) return txAbort;
        final s = WaitingSlot.fromJson(cur);
        if (s.uid != uid || s.takenBy != null) return txAbort;
        return WaitingSlot(
          uid: s.uid,
          roomId: s.roomId,
          name: s.name,
          t: serverNow,
        ).toJson();
      });

  /// 내 자리면 지운다. onDisconnect도 취소.
  Future<void> leaveSlot(String uid) async {
    await _db.cancelOnDisconnect(_slot);
    await _db.transaction(
      _slot,
      (cur) =>
          cur != null && WaitingSlot.fromJson(cur).uid == uid ? null : txAbort,
    );
  }

  Stream<WaitingSlot?> slot() =>
      _db.watch(_slot).map((v) => v == null ? null : WaitingSlot.fromJson(v));

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

  // ---------------------------------------------------------- 전투

  /// uid → 체력.
  Stream<Map<String, NetHp>> hp(String code) =>
      _db.watch('${_room(code)}/hp').map((v) {
        final m = (v as Map<Object?, Object?>?) ?? const {};
        return {
          for (final e in m.entries) e.key! as String: NetHp.fromJson(e.value),
        };
      });

  /// 본인만: 부활(체력 가득 + 보호 시간).
  Future<void> setHp(String code, String uid, NetHp hp) =>
      _db.set('${_room(code)}/hp/$uid', hp.toJson());

  /// [victim]의 체력을 트랜잭션으로 깎는다. [next]가 지금 체력으로 새 값을 만든다
  /// (null이면 중단: 이미 0이거나 보호 중). 썼으면 전후 값, 아니면 null.
  Future<({double before, double after})?> damage(
    String code,
    String victim,
    double? Function(NetHp current) next,
  ) async {
    late double before;
    try {
      final r = await _db.transaction('${_room(code)}/hp/$victim', (cur) {
        if (cur == null) return txAbort;
        final hp = NetHp.fromJson(cur);
        final value = next(hp);
        if (value == null) return txAbort;
        before = hp.value;
        return NetHp(value: value, protectedUntil: hp.protectedUntil).toJson();
      });
      if (!r.committed) return null;
      return (before: before, after: NetHp.fromJson(r.value).value);
    } catch (_) {
      // 규칙 거부(서버가 보기엔 아직 보호 중 등)는 안 맞은 것으로 친다.
      return null;
    }
  }

  Future<void> recordKill(String code, NetKill k) =>
      _db.push('${_room(code)}/kills', {...k.toJson(), 't': serverTimestamp});

  Stream<NetKill> kills(String code) =>
      _db.childAdded('${_room(code)}/kills').map(NetKill.fromJson);

  /// 팀 점수 +1(트랜잭션).
  Future<void> addScore(String code, String team) => _db.transaction(
    '${_room(code)}/score/$team',
    (cur) => ((cur as num?)?.toInt() ?? 0) + 1,
  );

  /// 팀 → 점수.
  Stream<Map<String, int>> score(String code) =>
      _db.watch('${_room(code)}/score').map((v) {
        final m = (v as Map<Object?, Object?>?) ?? const {};
        return {
          for (final e in m.entries)
            e.key! as String: (e.value! as num).toInt(),
        };
      });

  Future<int> serverNow() async =>
      DateTime.now().millisecondsSinceEpoch + await serverTimeOffset().first;

  /// 서버 시간 − 내 시계(ms).
  Stream<int> serverTimeOffset() =>
      _db.watch('.info/serverTimeOffset').map((v) => (v as num?)?.toInt() ?? 0);
}
