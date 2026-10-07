import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/models/match_stats.dart';
import 'package:topsoldier/rules/match.dart';
import 'package:topsoldier/ui/result/result_view_model.dart';

void main() {
  test('accuracy = hits / shots, rounded percent', () {
    const vm = ResultViewModel(
      MatchStats(result: MatchResult.win, shots: 30, hits: 11),
    );
    expect(vm.accuracy, '37%');
  });

  test('no shots → 0%, not a division error', () {
    expect(
      const ResultViewModel(MatchStats(result: MatchResult.lose)).accuracy,
      '0%',
    );
  });

  test('title per result', () {
    String title(MatchResult r) => ResultViewModel(MatchStats(result: r)).title;
    expect(title(MatchResult.win), '승리');
    expect(title(MatchResult.lose), '패배');
    expect(title(MatchResult.draw), '무승부');
  });

  test('rows show kills, deaths, accuracy, crits', () {
    const vm = ResultViewModel(
      MatchStats(
        result: MatchResult.win,
        kills: 4,
        deaths: 2,
        shots: 10,
        hits: 5,
        crits: 1,
      ),
    );
    expect(vm.rows, [
      ('킬', '4'),
      ('데스', '2'),
      ('명중률', '50%  (5 / 10)'),
      ('크리티컬', '1'),
    ]);
  });
}
