import '../../rules/match.dart';

/// 한 판의 내 기록. 결과 화면에 보여 주고 보상·전적으로 저장한다.
class MatchStats {
  const MatchStats({
    required this.matchId,
    required this.result,
    this.kills = 0,
    this.deaths = 0,
    this.shots = 0,
    this.hits = 0,
    this.crits = 0,
    this.ownScore,
    this.enemyScore,
  });

  /// 이 매치를 가리키는 값(방 + 끝나는 시각). 보상이 두 번 더해지지 않게.
  final String matchId;
  final MatchResult result;
  final int kills;
  final int deaths;

  /// 쏜 총알(샷건은 펠릿마다).
  final int shots;

  /// 상대 몸에 닿고 미스가 아니었던 총알.
  final int hits;
  final int crits;

  /// 2대2 팀 점수(내 팀, 상대 팀). 1대1은 null.
  final int? ownScore;
  final int? enemyScore;
}
