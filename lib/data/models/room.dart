/// RTDB `rooms/{code}` 아래 데이터 (decisions 13장).
// ponytail: copyWith 없음. 이 모델들은 받은 그대로 쓰고 고쳐 쓰는 곳이 없다. 생기면 추가.
library;

Map<Object?, Object?> _map(Object? v) => v as Map<Object?, Object?>;
double _d(Object? v) => (v as num).toDouble();
int _i(Object? v) => (v as num?)?.toInt() ?? 0;

/// `rooms/{code}/meta`
class RoomMeta {
  const RoomMeta({
    required this.hostUid,
    required this.status,
    this.endsAt = 0,
    this.winner,
  });

  factory RoomMeta.fromJson(Object? json) {
    final m = _map(json);
    return RoomMeta(
      hostUid: m['hostUid'] as String,
      status: m['status'] as String,
      endsAt: _i(m['endsAt']),
      winner: m['winner'] as String?,
    );
  }

  static const waiting = 'waiting';
  static const playing = 'playing';
  static const ended = 'ended';

  /// [winner] 값.
  static const teamA = 'A';
  static const teamB = 'B';
  static const draw = 'draw';

  final String hostUid;

  /// [waiting] → [playing] → [ended].
  final String status;

  /// 서버 시간(ms). 시작 전엔 0.
  final int endsAt;

  /// [teamA], [teamB], [draw]. 끝나기 전엔 null.
  final String? winner;
}

/// `rooms/{code}/players/{uid}`
class RoomPlayer {
  const RoomPlayer({
    required this.uid,
    required this.name,
    required this.connected,
    this.team = RoomMeta.teamA,
  });

  factory RoomPlayer.fromJson(String uid, Object? json) {
    final m = _map(json);
    return RoomPlayer(
      uid: uid,
      name: m['name'] as String? ?? '',
      connected: m['connected'] as bool? ?? false,
      team: m['team'] as String? ?? RoomMeta.teamA,
    );
  }

  final String uid;
  final String name;
  final bool connected;

  /// 방장 A(남쪽), 참가자 B(북쪽).
  final String team;
}

/// `rooms/{code}/hp/{uid}`. 맞힌 쪽이 트랜잭션으로 깎는다.
class NetHp {
  const NetHp({required this.value, required this.protectedUntil});

  factory NetHp.fromJson(Object? json) {
    final m = _map(json);
    return NetHp(
      value: _d(m['value']),
      protectedUntil: _i(m['protectedUntil']),
    );
  }

  final double value;

  /// 서버 시간(ms). 이 전까지 부활 무적.
  final int protectedUntil;

  Map<String, Object?> toJson() => {
    'value': value,
    'protectedUntil': protectedUntil,
  };
}

/// `rooms/{code}/kills/{id}`. 킬 로그.
class NetKill {
  const NetKill({
    required this.killer,
    required this.victim,
    required this.weapon,
    required this.crit,
  });

  factory NetKill.fromJson(Object? json) {
    final m = _map(json);
    return NetKill(
      killer: m['killer'] as String,
      victim: m['victim'] as String,
      weapon: m['weapon'] as String,
      crit: m['crit'] as bool? ?? false,
    );
  }

  final String killer;
  final String victim;
  final String weapon;
  final bool crit;

  Map<String, Object?> toJson() => {
    'killer': killer,
    'victim': victim,
    'weapon': weapon,
    'crit': crit,
  };
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
