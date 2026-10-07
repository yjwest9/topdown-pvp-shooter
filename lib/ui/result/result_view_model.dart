import '../../data/models/match_stats.dart';
import '../../rules/match.dart';

/// 결과 화면에 보일 글자들. 바뀌는 상태가 없어서 Notifier 없이 값으로 만든다.
class ResultViewModel {
  const ResultViewModel(this.stats);

  final MatchStats stats;

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
  ];
}
