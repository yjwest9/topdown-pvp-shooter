import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/models/holiday.dart';
import 'package:topsoldier/data/models/match_stats.dart';
import 'package:topsoldier/data/models/profile.dart';
import 'package:topsoldier/rules/match.dart';
import 'package:topsoldier/rules/rewards.dart';
import 'package:topsoldier/ui/result/result_view_model.dart';

void main() {
  test('accuracy = hits / shots, rounded percent', () {
    const vm = ResultViewModel(
      MatchStats(matchId: 'm', result: MatchResult.win, shots: 30, hits: 11),
    );
    expect(vm.accuracy, '37%');
  });

  test('no shots → 0%, not a division error', () {
    expect(
      const ResultViewModel(MatchStats(matchId: 'm', result: MatchResult.lose))
          .accuracy,
      '0%',
    );
  });

  test('title per result', () {
    String title(MatchResult r) =>
        ResultViewModel(MatchStats(matchId: 'm', result: r)).title;
    expect(title(MatchResult.win), '승리');
    expect(title(MatchResult.lose), '패배');
    expect(title(MatchResult.draw), '무승부');
  });

  test('rows show kills, deaths, accuracy, crits', () {
    const vm = ResultViewModel(
      MatchStats(
        matchId: 'm',
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

  test('holiday event adds a reward multiplier row', () {
    final vm = ResultViewModel(
      const MatchStats(matchId: 'm', result: MatchResult.win),
      holiday: Holiday(date: DateTime(2026, 10, 9), name: '한글날'),
    );
    expect(vm.rows.last, ('이벤트', '한글날 보상 ×2'));
    expect(
      const ResultViewModel(MatchStats(matchId: 'm', result: MatchResult.win))
          .rows,
      hasLength(4),
    );
  });

  test('reward text: gold, exp (bot match is half)', () {
    const stats = MatchStats(matchId: 'm', result: MatchResult.win, kills: 3);
    const pvp = ResultViewModel(stats);
    expect((pvp.goldText, pvp.expText), ('+5,600 G', '+130 EXP'));
    const bot = ResultViewModel(stats, mode: MatchMode.bot);
    expect((bot.goldText, bot.expText), ('+2,800 G', '+65 EXP'));
  });

  test('applyTo adds gold, exp (levels up) and stats', () {
    const vm = ResultViewModel(
      MatchStats(matchId: 'm', result: MatchResult.win, kills: 3, deaths: 2),
    );
    final p = vm.applyTo(const Profile(nickname: 'A', exp: 90, gold: 100));
    expect((p.gold, p.level, p.exp), (5700, 2, 120)); // 90 + 130 = 220 → 100 넘김
    expect((p.matches, p.wins, p.kills, p.deaths), (1, 1, 3, 2));
  });

  test('level up text only when the level changed', () {
    expect(
      ResultViewModel.levelUpText(
        const Profile(nickname: 'A', level: 3),
        const Profile(nickname: 'A', level: 4),
      ),
      'LEVEL UP! 3 → 4',
    );
    expect(
      ResultViewModel.levelUpText(
        const Profile(nickname: 'A', level: 3),
        const Profile(nickname: 'A', level: 3),
      ),
      isNull,
    );
  });

  test('forfeit: counted as a played loss, no reward', () {
    const vm = ResultViewModel(
      MatchStats(matchId: 'm', result: MatchResult.lose, kills: 2, deaths: 1),
      forfeit: true,
    );
    final p = vm.applyTo(const Profile(nickname: 'A', gold: 100, exp: 10));
    expect((p.gold, p.exp, p.level), (100, 10, 1));
    expect((p.matches, p.wins, p.kills, p.deaths), (1, 0, 2, 1));
  });

  test('custom room: stats saved, no reward. training: not saved', () {
    const stats = MatchStats(matchId: 'm', result: MatchResult.win, kills: 2);
    expect(const ResultViewModel(stats).saves, true);
    expect(const ResultViewModel(stats, mode: MatchMode.bot).saves, true);
    const custom = ResultViewModel(stats, mode: MatchMode.custom);
    expect((custom.saves, custom.rewarded), (true, false));
    final p = custom.applyTo(const Profile(nickname: 'A', gold: 100));
    expect((p.gold, p.exp, p.matches, p.wins, p.kills), (100, 0, 1, 1, 2));
    expect(const ResultViewModel(stats, mode: MatchMode.training).saves, false);
  });

  test(
    '2v2 result shows the team score (own : enemy); 1v1 has no such row',
    () {
      const two = ResultViewModel(
        MatchStats(
          matchId: 'm',
          result: MatchResult.win,
          kills: 4,
          deaths: 3,
          ownScore: 12,
          enemyScore: 9,
        ),
        mode: MatchMode.custom,
      );
      expect(two.rows, contains(('팀 점수', '12 : 9')));
      expect(two.rewarded, false); // 친선전: 보상 없음
      expect(two.saves, true); // 전적은 친선전과 같게

      const one = ResultViewModel(
        MatchStats(matchId: 'm', result: MatchResult.win),
        mode: MatchMode.custom,
      );
      expect(one.rows.any((r) => r.$1 == '팀 점수'), false);
    },
  );
}
