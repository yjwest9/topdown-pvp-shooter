import 'balance.dart';
import 'match.dart';

/// 보상 규칙이 달라지는 매치 종류.
enum MatchMode {
  /// 빠른 대전(실시간). 보상 100%, 중간에 나가면 패배.
  pvp,

  /// 봇전. 보상 [botRewardRate].
  bot,

  /// 방 만들기·코드 입장(친선전). 보상·전적 없음.
  custom,

  /// 훈련소. 보상 없음.
  training,
}

typedef Reward = ({int gold, int exp});

/// 한 판의 골드·경험치(decisions 9장). [holiday]면 공휴일 이벤트 배율.
/// [forfeit]면 중간에 나간 것(패배, 보상 없음).
Reward matchReward({
  required MatchResult result,
  required int kills,
  required MatchMode mode,
  bool holiday = false,
  bool forfeit = false,
}) {
  if (forfeit) return (gold: 0, exp: 0);
  final win = result == MatchResult.win;
  final rate =
      switch (mode) {
        MatchMode.pvp => 1.0,
        MatchMode.bot => botRewardRate,
        MatchMode.custom || MatchMode.training => 0.0,
      } *
      (holiday ? holidayRewardMultiplier : 1);
  return (
    gold: (((win ? winGold : loseGold) + kills * killGold) * rate).round(),
    exp: (((win ? winExp : loseExp) + kills * killExp) * rate).round(),
  );
}

/// 결과 화면 광고(decisions 10장)로 더 받는 골드. 그 판 골드 보상 [matchGold]를 [resultAdMultiplier]배로
/// 만드는 만큼이고, 보상이 0이거나 이미 받았으면([claimed], 판당 1회) 0.
int resultAdBonus(int matchGold, {required bool claimed}) =>
    claimed || matchGold <= 0 ? 0 : matchGold * (resultAdMultiplier - 1);
