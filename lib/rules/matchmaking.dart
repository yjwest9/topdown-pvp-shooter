import 'balance.dart';

/// 빠른 매칭 대기석 `matchmaking/1v1/waiting`에서 판정에 쓰는 값(decisions 13장).
typedef QuickMatchSlot = ({String uid, int t, String? takenBy});

enum QuickMatchAction {
  /// 내가 앉는다(내 방, 방장).
  claim,

  /// 이미 내 자리다. 계속 기다린다.
  wait,

  /// 남의 자리에 takenBy = 나. 그 방에 들어간다.
  take,

  /// 누가 이미 잡았다. 잠시 뒤 다시.
  retry,
}

/// 대기석 트랜잭션 안에서 부른다. [serverNow]는 서버 시간 추정값(ms).
QuickMatchAction decideQuickMatch(
  QuickMatchSlot? slot,
  String myUid,
  int serverNow,
) {
  if (slot == null || serverNow - slot.t > quickMatchStaleMs) {
    return QuickMatchAction.claim;
  }
  if (slot.uid == myUid) return QuickMatchAction.wait;
  if (slot.takenBy == null) return QuickMatchAction.take;
  return QuickMatchAction.retry;
}
