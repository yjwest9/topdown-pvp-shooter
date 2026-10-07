import '../../rules/match.dart';

/// 한 판의 내 기록. 결과 화면에 보여 준다(전적 저장은 다음).
class MatchStats {
  const MatchStats({
    required this.result,
    this.kills = 0,
    this.deaths = 0,
    this.shots = 0,
    this.hits = 0,
    this.crits = 0,
  });

  final MatchResult result;
  final int kills;
  final int deaths;

  /// 쏜 총알(샷건은 펠릿마다).
  final int shots;

  /// 상대 몸에 닿고 미스가 아니었던 총알.
  final int hits;
  final int crits;
}
