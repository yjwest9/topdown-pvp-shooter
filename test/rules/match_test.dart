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
}
