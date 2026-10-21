/// 앱을 다시 켰을 때 남아 있는 `activeMatch`(빠른 대전 도중 강제 종료)를 어떻게 할지(decisions 9장).
enum ActiveMatchAction {
  /// 표시가 없다: 할 일 없음.
  none,

  /// 끝내지 않고 나간 판: 패배(보상 0)로 한 번 저장하고 표시를 지운다.
  recordLoss,

  /// 이미 결과가 저장된 판(저장은 됐는데 표시만 남음): 표시만 지운다. 두 번 세지 않는다.
  clearOnly,
}

ActiveMatchAction activeMatchAction({
  required String? activeMatchId,
  required String? lastMatchId,
}) {
  if (activeMatchId == null) return ActiveMatchAction.none;
  return activeMatchId == lastMatchId
      ? ActiveMatchAction.clearOnly
      : ActiveMatchAction.recordLoss;
}
