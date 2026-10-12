/// `users/{uid}/weapons/{id}`. 보유 무기 한 개(decisions 6·7장).
class OwnedWeapon {
  const OwnedWeapon({
    required this.id,
    required this.weaponId,
    this.grade = 'E',
    this.level = 0,
  });

  factory OwnedWeapon.fromJson(String id, Object? json) {
    final m = json! as Map<Object?, Object?>;
    return OwnedWeapon(
      id: id,
      weaponId: m['weaponId'] as String,
      grade: m['grade'] as String? ?? 'E',
      level: (m['level'] as num?)?.toInt() ?? 0,
    );
  }

  /// 개체 id(같은 무기를 여러 개 가질 수 있다).
  final String id;

  /// 무기 표의 id(`rifle_standard` 등).
  final String weaponId;
  final String grade;
  final int level;

  /// acquiredAt은 쓸 때만 넣는다.
  Map<String, Object?> toJson(int acquiredAt) => {
    'weaponId': weaponId,
    'grade': grade,
    'level': level,
    'acquiredAt': acquiredAt,
  };
}

/// RTDB `users/{uid}` (decisions 9장, 13장).
class Profile {
  const Profile({
    required this.nickname,
    this.level = 1,
    this.exp = 0,
    this.gold = 0,
    this.diamond = 0,
    this.matches = 0,
    this.wins = 0,
    this.kills = 0,
    this.deaths = 0,
    this.lastMatchId,
    this.weapons = const [],
    this.primaryId,
    this.secondaryId,
  });

  factory Profile.fromJson(Object? json) {
    final m = json! as Map<Object?, Object?>;
    final s = (m['stats'] as Map<Object?, Object?>?) ?? const {};
    final w = (m['weapons'] as Map<Object?, Object?>?) ?? const {};
    final l = (m['loadout'] as Map<Object?, Object?>?) ?? const {};
    int i(Object? v) => (v as num?)?.toInt() ?? 0;
    return Profile(
      nickname: m['nickname'] as String? ?? '',
      level: (m['level'] as num?)?.toInt() ?? 1,
      exp: i(m['exp']),
      gold: i(m['gold']),
      diamond: i(m['diamond']),
      matches: i(s['matches']),
      wins: i(s['wins']),
      kills: i(s['kills']),
      deaths: i(s['deaths']),
      lastMatchId: m['lastMatchId'] as String?,
      weapons: [
        for (final e in w.entries)
          OwnedWeapon.fromJson(e.key! as String, e.value),
      ],
      primaryId: l['primary'] as String?,
      secondaryId: l['secondary'] as String?,
    );
  }

  final String nickname;
  final int level;

  /// 지금 레벨 안에서 쌓인 경험치.
  final int exp;
  final int gold;
  final int diamond;
  final int matches;
  final int wins;
  final int kills;
  final int deaths;

  /// 마지막으로 보상을 받은 매치. 같은 결과가 두 번 더해지지 않게.
  final String? lastMatchId;

  /// 보유 무기. [toJson]에는 없다(트랜잭션은 원래 값에 덮어쓰므로 그대로 남는다).
  final List<OwnedWeapon> weapons;

  /// 로드아웃: 장착한 무기 개체 id. 없으면 기본 무기 지급 전.
  final String? primaryId;
  final String? secondaryId;

  bool get hasLoadout => primaryId != null && secondaryId != null;

  OwnedWeapon? owned(String weaponId) {
    for (final w in weapons) {
      if (w.weaponId == weaponId) return w;
    }
    return null;
  }

  OwnedWeapon? byId(String? id) {
    for (final w in weapons) {
      if (w.id == id) return w;
    }
    return null;
  }

  Profile copyWith({
    String? nickname,
    int? level,
    int? exp,
    int? gold,
    int? diamond,
    int? matches,
    int? wins,
    int? kills,
    int? deaths,
    String? lastMatchId,
  }) => Profile(
    nickname: nickname ?? this.nickname,
    level: level ?? this.level,
    exp: exp ?? this.exp,
    gold: gold ?? this.gold,
    diamond: diamond ?? this.diamond,
    matches: matches ?? this.matches,
    wins: wins ?? this.wins,
    kills: kills ?? this.kills,
    deaths: deaths ?? this.deaths,
    lastMatchId: lastMatchId ?? this.lastMatchId,
    weapons: weapons,
    primaryId: primaryId,
    secondaryId: secondaryId,
  );

  /// createdAt은 따로 쓴다(서버 시간).
  Map<String, Object?> toJson() => {
    'nickname': nickname,
    'level': level,
    'exp': exp,
    'gold': gold,
    'diamond': diamond,
    'stats': {
      'matches': matches,
      'wins': wins,
      'kills': kills,
      'deaths': deaths,
    },
    'lastMatchId': ?lastMatchId,
  };
}
