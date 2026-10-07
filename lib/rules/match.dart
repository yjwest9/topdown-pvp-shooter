import 'dart:math';

import 'balance.dart';

/// 매치 진행 상태. A = 방장 팀(남쪽), B = 참가자 팀(북쪽).
enum MatchOutcome { ongoing, aWins, bWins, draw }

/// 내 입장에서 본 결과.
enum MatchResult { win, lose, draw }

/// 맞힌 쪽이 hp 트랜잭션 안에서 부른다. 새 체력, 또는 중단이면 null
/// (이미 0이거나 부활 보호 중).
double? applyDamage({
  required double value,
  required int protectedUntil,
  required double damage,
  required int serverNow,
}) {
  if (value <= 0 || protectedUntil > serverNow) return null;
  return max(0, value - damage);
}

/// 이 변화가 체력을 0으로 만들었으면 킬.
bool isKill(double before, double after) => before > 0 && after <= 0;

/// 한쪽이 나가면 남은 쪽 승리 → [killsToWin] 선취 → 시간 끝나면 점수 비교.
MatchOutcome matchEndState({
  required int scoreA,
  required int scoreB,
  required int remainingMs,
  required bool aConnected,
  required bool bConnected,
}) {
  if (aConnected != bConnected) {
    return aConnected ? MatchOutcome.aWins : MatchOutcome.bWins;
  }
  if (scoreA >= killsToWin) return MatchOutcome.aWins;
  if (scoreB >= killsToWin) return MatchOutcome.bWins;
  if (remainingMs > 0) return MatchOutcome.ongoing;
  if (scoreA == scoreB) return MatchOutcome.draw;
  return scoreA > scoreB ? MatchOutcome.aWins : MatchOutcome.bWins;
}

MatchResult resultFor(MatchOutcome o, {required bool teamA}) => switch (o) {
  MatchOutcome.draw || MatchOutcome.ongoing => MatchResult.draw,
  MatchOutcome.aWins => teamA ? MatchResult.win : MatchResult.lose,
  MatchOutcome.bWins => teamA ? MatchResult.lose : MatchResult.win,
};
