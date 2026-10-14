import 'balance.dart';

/// 광고를 다시 보기까지 남은 시간(decisions 9장). [lastAdAt]·[now]는 서버 시간 ms.
/// 시계 차이로 [lastAdAt]이 미래여도 [adCooldown]을 넘지 않는다.
Duration adCooldownLeft(int? lastAdAt, int now) {
  if (lastAdAt == null) return Duration.zero;
  final left = adCooldown.inMilliseconds - (now - lastAdAt);
  return Duration(milliseconds: left.clamp(0, adCooldown.inMilliseconds));
}

/// 환전 한 번. 골드가 모자라면 null.
({int gold, int diamond})? exchangeGold({
  required int gold,
  required int diamond,
}) => gold < exchangeGoldCost
    ? null
    : (gold: gold - exchangeGoldCost, diamond: diamond + exchangeDiamonds);
