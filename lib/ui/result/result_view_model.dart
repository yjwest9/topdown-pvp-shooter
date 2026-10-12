import '../../data/models/holiday.dart';
import '../../data/models/match_stats.dart';
import '../../data/models/profile.dart';
import '../../rules/balance.dart';
import '../../rules/match.dart';
import '../../rules/profile.dart';
import '../../rules/rewards.dart';
import '../format.dart';

/// 결과 화면에 보일 글자들과 보상. 바뀌는 상태가 없어서 Notifier 없이 값으로 만든다.
class ResultViewModel {
  const ResultViewModel(
    this.stats, {
    this.holiday,
    this.mode = MatchMode.pvp,
    this.forfeit = false,
  });

  final MatchStats stats;

  /// 오늘 공휴일 이벤트(보상 배율).
  final Holiday? holiday;
  final MatchMode mode;

  /// 중간에 나감: 패배로 기록, 보상 없음.
  final bool forfeit;

  /// 프로필에 전적을 저장하는 매치. 훈련소만 빼고.
  bool get saves => mode != MatchMode.training;

  /// 골드·경험치를 주는 매치(빠른 대전, 봇전). 친선전은 전적만.
  bool get rewarded => mode == MatchMode.pvp || mode == MatchMode.bot;

  String get title => switch (stats.result) {
    MatchResult.win => '승리',
    MatchResult.lose => '패배',
    MatchResult.draw => '무승부',
  };

  /// 내가 맞힌 총알 / 쏜 총알.
  String get accuracy =>
      stats.shots == 0 ? '0%' : '${(stats.hits / stats.shots * 100).round()}%';

  List<(String, String)> get rows => [
    ('킬', '${stats.kills}'),
    ('데스', '${stats.deaths}'),
    ('명중률', '$accuracy  (${stats.hits} / ${stats.shots})'),
    ('크리티컬', '${stats.crits}'),
    if (holiday case final h?)
      ('이벤트', '${h.name} 보상 ×$holidayRewardMultiplier'),
  ];

  Reward get reward => matchReward(
    result: stats.result,
    kills: stats.kills,
    mode: mode,
    holiday: holiday != null,
    forfeit: forfeit,
  );

  String get goldText => '+${commas(reward.gold)} G';
  String get expText => '+${commas(reward.exp)} EXP';

  /// 이 판의 보상과 전적을 더한 프로필.
  Profile applyTo(Profile p) {
    final r = reward;
    final l = addExp(level: p.level, exp: p.exp, gained: r.exp);
    return p.copyWith(
      gold: p.gold + r.gold,
      level: l.level,
      exp: l.exp,
      matches: p.matches + 1,
      wins: p.wins + (stats.result == MatchResult.win ? 1 : 0),
      kills: p.kills + stats.kills,
      deaths: p.deaths + stats.deaths,
    );
  }

  static String? levelUpText(Profile before, Profile after) =>
      after.level > before.level
      ? 'LEVEL UP! ${before.level} → ${after.level}'
      : null;
}
