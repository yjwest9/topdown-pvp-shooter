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
  });

  factory Profile.fromJson(Object? json) {
    final m = json! as Map<Object?, Object?>;
    final s = (m['stats'] as Map<Object?, Object?>?) ?? const {};
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
