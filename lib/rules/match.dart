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

/// 한 팀 킬 합계 승리 기준. 1대1은 [killsToWin], 2대2는 [killsToWin2v2].
int killsToWinFor(int teamSize) => teamSize == 2 ? killsToWin2v2 : killsToWin;

/// [team]에 연결된 사람이 하나도 없다(전원 이탈).
bool teamGone(Iterable<({String team, bool connected})> players, String team) =>
    !players.any((p) => p.team == team && p.connected);

/// 한쪽이 나가면 남은 쪽 승리 → [toWin] 선취 → 시간 끝나면 점수 비교.
/// [aConnected]·[bConnected]는 그 팀에 연결된 사람이 있는지.
MatchOutcome matchEndState({
  required int scoreA,
  required int scoreB,
  required int remainingMs,
  required bool aConnected,
  required bool bConnected,
  int toWin = killsToWin,
}) {
  if (aConnected != bConnected) {
    return aConnected ? MatchOutcome.aWins : MatchOutcome.bWins;
  }
  if (scoreA >= toWin) return MatchOutcome.aWins;
  if (scoreB >= toWin) return MatchOutcome.bWins;
  if (remainingMs > 0) return MatchOutcome.ongoing;
  if (scoreA == scoreB) return MatchOutcome.draw;
  return scoreA > scoreB ? MatchOutcome.aWins : MatchOutcome.bWins;
}

MatchResult resultFor(MatchOutcome o, {required bool teamA}) => switch (o) {
  MatchOutcome.draw || MatchOutcome.ongoing => MatchResult.draw,
  MatchOutcome.aWins => teamA ? MatchResult.win : MatchResult.lose,
  MatchOutcome.bWins => teamA ? MatchResult.lose : MatchResult.win,
};
