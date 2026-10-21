import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/match.dart';

void main() {
  group('applyDamage', () {
    test('subtracts damage', () {
      expect(
        applyDamage(value: 100, protectedUntil: 0, damage: 13, serverNow: 10),
        87,
      );
    });

    test('never goes below 0', () {
      expect(
        applyDamage(value: 5, protectedUntil: 0, damage: 13, serverNow: 10),
        0,
      );
    });

    test('aborts when already 0', () {
      expect(
        applyDamage(value: 0, protectedUntil: 0, damage: 13, serverNow: 10),
        isNull,
      );
    });

    test('aborts while spawn-protected, applies right after', () {
      expect(
        applyDamage(
          value: 100,
          protectedUntil: 5000,
          damage: 13,
          serverNow: 4999,
        ),
        isNull,
      );
      expect(
        applyDamage(
          value: 100,
          protectedUntil: 5000,
          damage: 13,
          serverNow: 5000,
        ),
        87,
      );
    });
  });

  test('isKill only when this change took hp to 0', () {
    expect(isKill(13, 0), true);
    expect(isKill(100, 87), false);
    expect(isKill(0, 0), false);
  });

  group('matchEndState', () {
    MatchOutcome end({
      int a = 0,
      int b = 0,
      int remainingMs = 60000,
      bool aOn = true,
      bool bOn = true,
    }) => matchEndState(
      scoreA: a,
      scoreB: b,
      remainingMs: remainingMs,
      aConnected: aOn,
      bConnected: bOn,
    );

    test('ongoing while time left and below kill target', () {
      expect(end(a: 3, b: 1), MatchOutcome.ongoing);
    });

    test('match is 3 minutes, first to 7 kills (decisions 12장)', () {
      expect(matchDurationMs, 180000);
      expect(end(a: 6, b: 6), MatchOutcome.ongoing);
      expect(end(a: 7, b: 6), MatchOutcome.aWins);
    });

    test('first to $killsToWin kills wins', () {
      expect(end(a: killsToWin, b: 5), MatchOutcome.aWins);
      expect(end(a: 2, b: killsToWin), MatchOutcome.bWins);
    });

    test('time up: higher score wins, equal is a draw', () {
      expect(end(a: 3, b: 1, remainingMs: 0), MatchOutcome.aWins);
      expect(end(a: 1, b: 4, remainingMs: -5), MatchOutcome.bWins);
      expect(end(a: 2, b: 2, remainingMs: 0), MatchOutcome.draw);
    });

    test('the team that stays wins when the other leaves', () {
      expect(end(a: 0, b: 9, bOn: false), MatchOutcome.aWins);
      expect(end(a: 9, b: 0, aOn: false), MatchOutcome.bWins);
    });
  });

  test('resultFor maps the outcome to my side', () {
    expect(resultFor(MatchOutcome.aWins, teamA: true), MatchResult.win);
    expect(resultFor(MatchOutcome.aWins, teamA: false), MatchResult.lose);
    expect(resultFor(MatchOutcome.bWins, teamA: false), MatchResult.win);
    expect(resultFor(MatchOutcome.draw, teamA: true), MatchResult.draw);
  });

  group('2v2 (decisions 12장): team kills to 12, time, draw, team gone', () {
    MatchOutcome end({
      int a = 0,
      int b = 0,
      int ms = 60000,
      bool aOn = true,
      bool bOn = true,
    }) => matchEndState(
      scoreA: a,
      scoreB: b,
      remainingMs: ms,
      aConnected: aOn,
      bConnected: bOn,
      toWin: killsToWinFor(2),
    );

    test('12 kills for a team, not 7; 1v1 stays at 7', () {
      expect(killsToWin2v2, 12);
      expect(killsToWinFor(2), 12);
      expect(killsToWinFor(1), 7);
      expect(end(a: 7, b: 6), MatchOutcome.ongoing);
      expect(end(a: 11, b: 3), MatchOutcome.ongoing);
      expect(end(a: 12, b: 3), MatchOutcome.aWins);
      expect(end(a: 4, b: 12), MatchOutcome.bWins);
      // 1대1 기준은 그대로.
      expect(
        matchEndState(
          scoreA: 7,
          scoreB: 0,
          remainingMs: 1000,
          aConnected: true,
          bConnected: true,
        ),
        MatchOutcome.aWins,
      );
    });

    test('time over: higher team score wins, equal is a draw', () {
      expect(end(a: 9, b: 8, ms: 0), MatchOutcome.aWins);
      expect(end(a: 8, b: 9, ms: 0), MatchOutcome.bWins);
      expect(end(a: 8, b: 8, ms: 0), MatchOutcome.draw);
      expect(end(a: 0, b: 0, ms: 0), MatchOutcome.draw);
    });

    test('a whole team gone → the other team wins; one gone → keep going', () {
      final all = [
        (team: 'A', connected: true),
        (team: 'A', connected: true),
        (team: 'B', connected: true),
        (team: 'B', connected: true),
      ];
      expect(teamGone(all, 'B'), false);
      final oneLeft = [...all]..[3] = (team: 'B', connected: false);
      expect(teamGone(oneLeft, 'B'), false); // 2대1은 계속
      final bothLeft = [...oneLeft]..[2] = (team: 'B', connected: false);
      expect(teamGone(bothLeft, 'B'), true);
      expect(teamGone(bothLeft, 'A'), false);
      expect(end(aOn: true, bOn: !teamGone(bothLeft, 'B')), MatchOutcome.aWins);
      expect(
        end(aOn: true, bOn: !teamGone(oneLeft, 'B')),
        MatchOutcome.ongoing,
      );
    });
  });
}
