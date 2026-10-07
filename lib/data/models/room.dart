/// RTDB `rooms/{code}` 아래 데이터 (decisions 13장).
// ponytail: copyWith 없음. 이 모델들은 받은 그대로 쓰고 고쳐 쓰는 곳이 없다. 생기면 추가.
library;

Map<Object?, Object?> _map(Object? v) => v as Map<Object?, Object?>;
double _d(Object? v) => (v as num).toDouble();
int _i(Object? v) => (v as num?)?.toInt() ?? 0;

/// `rooms/{code}/meta`
class RoomMeta {
  const RoomMeta({required this.hostUid, required this.status});

  factory RoomMeta.fromJson(Object? json) {
    final m = _map(json);
    return RoomMeta(
      hostUid: m['hostUid'] as String,
      status: m['status'] as String,
    );
  }

  static const waiting = 'waiting';
  static const playing = 'playing';

  final String hostUid;

  /// [waiting] → [playing].
  final String status;
}

/// `rooms/{code}/players/{uid}`
class RoomPlayer {
  const RoomPlayer({
    required this.uid,
    required this.name,
    required this.connected,
  });

  factory RoomPlayer.fromJson(String uid, Object? json) {
    final m = _map(json);
    return RoomPlayer(
      uid: uid,
      name: m['name'] as String? ?? '',
      connected: m['connected'] as bool? ?? false,
    );
  }

  final String uid;
  final String name;
  final bool connected;
}

/// `rooms/{code}/states/{uid}`. 초당 15회 기록.
class NetState {
  const NetState({
    required this.x,
    required this.y,
    required this.a,
    required this.stance,
    required this.up,
    required this.weapon,
    this.t = 0,
  });

  factory NetState.fromJson(Object? json) {
    final m = _map(json);
    return NetState(
      x: _d(m['x']),
      y: _d(m['y']),
      a: _d(m['a']),
      stance: m['stance'] as String,
      up: _d(m['up']),
      weapon: m['weapon'] as String,
      t: _i(m['t']),
    );
  }

  final double x;
  final double y;

  /// 바라보는 방향(rad).
  final double a;

  /// `Stance` 이름(standing, walking, running, crouching, jumping).
  final String stance;

  /// 높이: 점프 중 0→1→0, 상자 위 +0.5.
  final double up;

  /// 든 무기 id.
  final String weapon;

  /// 서버 시간(ms). 보낼 때는 무시되고 서버가 채운다.
  final int t;

  Map<String, Object?> toJson() => {
    'x': x,
    'y': y,
    'a': a,
    'stance': stance,
    'up': up,
    'weapon': weapon,
  };
}

/// `rooms/{code}/shots/{id}`. 연출용 총알 한 발.
class NetShot {
  const NetShot({
    required this.by,
    required this.x,
    required this.y,
    required this.a,
    required this.weapon,
    this.t = 0,
  });

  factory NetShot.fromJson(Object? json) {
    final m = _map(json);
    return NetShot(
      by: m['by'] as String,
      x: _d(m['x']),
      y: _d(m['y']),
      a: _d(m['a']),
      weapon: m['weapon'] as String,
      t: _i(m['t']),
    );
  }

  final String by;
  final double x;
  final double y;
  final double a;
  final String weapon;

  /// 서버 시간(ms). 보낼 때는 무시되고 서버가 채운다.
  final int t;

  Map<String, Object?> toJson() => {
    'by': by,
    'x': x,
    'y': y,
    'a': a,
    'weapon': weapon,
  };
}
