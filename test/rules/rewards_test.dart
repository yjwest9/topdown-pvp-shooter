import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/match.dart';
import 'package:topsoldier/rules/profile.dart';
import 'package:topsoldier/rules/rewards.dart';

void main() {
  group('matchReward', () {
    test('win / lose / kills (decisions 9장)', () {
      expect(
        matchReward(result: MatchResult.win, kills: 3, mode: MatchMode.pvp),
        (gold: 5000 + 3 * 200, exp: 100 + 3 * 10),
      );
      expect(
        matchReward(result: MatchResult.lose, kills: 0, mode: MatchMode.pvp),
        (gold: 2500, exp: 50),
      );
    });

    test('draw counts as a loss', () {
      expect(
        matchReward(result: MatchResult.draw, kills: 1, mode: MatchMode.pvp),
        matchReward(result: MatchResult.lose, kills: 1, mode: MatchMode.pvp),
      );
    });

    test('bot match pays half', () {
      expect(
        matchReward(result: MatchResult.win, kills: 3, mode: MatchMode.bot),
        (gold: 2800, exp: 65),
      );
    });

    test('training pays nothing, even on a holiday', () {
      expect(
        matchReward(
          result: MatchResult.win,
          kills: 10,
          mode: MatchMode.training,
          holiday: true,
        ),
        (gold: 0, exp: 0),
      );
    });

    test('custom room (방 만들기) pays nothing', () {
      expect(
        matchReward(result: MatchResult.win, kills: 5, mode: MatchMode.custom),
        (gold: 0, exp: 0),
      );
    });

    test('leaving a match early (forfeit) pays nothing', () {
      expect(
        matchReward(
          result: MatchResult.lose,
          kills: 4,
          mode: MatchMode.pvp,
          holiday: true,
          forfeit: true,
        ),
        (gold: 0, exp: 0),
      );
    });

    test('holiday event doubles gold and exp (bot too)', () {
      expect(
        matchReward(
          result: MatchResult.win,
          kills: 3,
          mode: MatchMode.pvp,
          holiday: true,
        ),
        (gold: 11200, exp: 260),
      );
      expect(
        matchReward(
          result: MatchResult.lose,
          kills: 1,
          mode: MatchMode.bot,
          holiday: true,
        ),
        (gold: 2700, exp: 60),
      );
    });
  });

  group('resultAdBonus (decisions 10장)', () {
    test('pays the match gold once more', () {
      expect(resultAdBonus(5600, claimed: false), 5600);
      expect(resultAdBonus(2500, claimed: false), 2500);
    });

    test('no reward → no bonus; already claimed → no bonus', () {
      expect(resultAdBonus(0, claimed: false), 0);
      expect(resultAdBonus(5600, claimed: true), 0);
    });

    test('scales with resultAdMultiplier (2 = one extra copy)', () {
      expect(resultAdMultiplier, 2);
      expect(5600 + resultAdBonus(5600, claimed: false), 5600 * 2);
    });

    test('holiday ×2 gold is what gets doubled again', () {
      final g = matchReward(
        result: MatchResult.win,
        kills: 0,
        mode: MatchMode.pvp,
        holiday: true,
      ).gold;
      expect(resultAdBonus(g, claimed: false), g);
    });
  });

  group('levels', () {
    test('exp needed: 100 + 50 × (level − 1)', () {
      expect(expToNext(1), 100);
      expect(expToNext(2), 150);
      expect(expToNext(5), 300);
    });

    test('just below the boundary stays, exactly at it levels up', () {
      expect(addExp(level: 1, exp: 0, gained: 99), (level: 1, exp: 99));
      expect(addExp(level: 1, exp: 0, gained: 100), (level: 2, exp: 0));
      expect(addExp(level: 2, exp: 140, gained: 15), (level: 3, exp: 5));
    });

    test('one big gain can pass several levels', () {
      // 1→2: 100, 2→3: 150, 3→4: 200 → 450이면 4레벨 0, 남은 20
      expect(addExp(level: 1, exp: 0, gained: 470), (level: 4, exp: 20));
    });

    test('no gain, no change', () {
      expect(addExp(level: 7, exp: 33, gained: 0), (level: 7, exp: 33));
    });
  });

  group('nickname', () {
    test('2 to 12 characters', () {
      expect(nicknameError('a'), isNotNull);
      expect(nicknameError('ab'), isNull);
      expect(nicknameError('abcdefghijkl'), isNull);
      expect(nicknameError('abcdefghijklm'), isNotNull);
    });

    test('Korean, English letters and digits only', () {
      expect(nicknameError('솔저Soldier99'), isNull);
      expect(nicknameError('탑솔져'), isNull);
      expect(nicknameError('top soldier'), isNotNull); // 공백
      expect(nicknameError('top_soldier'), isNotNull);
      expect(nicknameError('ㅋㅋㅋ'), isNotNull); // 자모만
      expect(nicknameError('😀😀'), isNotNull);
    });
  });
}
