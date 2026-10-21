/// 친선전 2대2 대기실 규칙(decisions 12장). 팀 글자는 방 데이터와 같다("A", "B").
const teamAId = 'A';
const teamBId = 'B';

String otherTeam(String team) => team == teamAId ? teamBId : teamAId;

/// 방 meta `teamSize`. 1 또는 2, 없거나 이상한 값이면 1(옛 방·옛 앱 호환).
int teamSizeOf(Object? v) => v == 2 ? 2 : 1;

/// 정원 = teamSize × 2.
bool roomFull({required int count, required int teamSize}) =>
    count >= teamSize * 2;

/// 입장하면 인원이 적은 팀으로, 같으면 A. [a], [b]는 지금 각 팀 인원.
String assignTeam({required int a, required int b}) =>
    a <= b ? teamAId : teamBId;

/// 내 팀 말고 상대 팀([target])에 빈자리가 있어야 옮길 수 있다.
bool canMoveTo(
  String target, {
  required String myTeam,
  required int targetCount,
  required int teamSize,
}) => target != myTeam && targetCount < teamSize;

/// 방장이 시작할 수 있는 조건: 두 팀이 모두 [teamSize]명이고 처리 중인 자리 바꾸기가 없다.
bool canStartRoom({
  required int a,
  required int b,
  required int teamSize,
  required bool swapPending,
}) => a == teamSize && b == teamSize && !swapPending;

// ------------------------------------------------------------ 자리 바꾸기

/// 요청은 이 시간 안에 응답이 없으면 자동 취소(서버 시간 ms).
const swapTimeoutMs = 10000;

/// 방 참가자의 자리 바꾸기 관련 값. 각자 자기 노드에만 쓴다.
/// 요청: 요청자가 `swapTo`(상대 uid)와 `swapAt`(서버 시간). 수락: 상대가 자기 팀을 바꾸고
/// `swapAccepted`(요청자 uid). 거절: `swapDeclined`(요청자 uid).
typedef SwapPlayer = ({
  String uid,
  String team,
  bool connected,
  String? swapTo,
  int? swapAt,
  String? swapAccepted,
  String? swapDeclined,
});

bool swapFresh(int? swapAt, int now) =>
    swapAt != null && now - swapAt < swapTimeoutMs;

SwapPlayer? _find(List<SwapPlayer> players, String? uid) {
  for (final p in players) {
    if (p.uid == uid) return p;
  }
  return null;
}

enum SwapBlock { ok, iAmBusy, notConnected, sameTeam, targetBusy }

/// 나([me])에게 온 요청 중 가장 먼저 쓴 유효한 것(요청자가 연결돼 있고 상대 팀이고 시간 안).
/// 내가 먼저 건 요청이 있으면 나중에 온 요청은 무시한다(서로 동시에 요청한 경우 먼저 쓴 쪽이 이김).
SwapPlayer? incomingSwap(String me, List<SwapPlayer> players, int now) {
  final mine = _find(players, me);
  if (mine == null || !mine.connected) return null;
  final myOut = swapFresh(mine.swapAt, now) && mine.swapTo != null;
  SwapPlayer? best;
  for (final p in players) {
    if (p.uid == me || !p.connected) continue;
    if (p.swapTo != me || !swapFresh(p.swapAt, now)) continue;
    if (p.team == mine.team) continue;
    if (myOut && mine.swapAt! <= p.swapAt!) continue;
    if (best == null || p.swapAt! < best.swapAt!) best = p;
  }
  return best;
}

/// 내가 [target]에게 자리 바꾸기를 요청할 수 있는지. 한 번에 하나: 나는 요청 중이거나 응답할
/// 요청이 있으면 안 되고, 상대도 다른 요청에 얽혀 있으면 안 된다.
SwapBlock canRequestSwap({
  required String me,
  required String target,
  required List<SwapPlayer> players,
  required int now,
}) {
  final mine = _find(players, me);
  final other = _find(players, target);
  if (mine == null) return SwapBlock.notConnected;
  if ((mine.swapTo != null && swapFresh(mine.swapAt, now)) ||
      incomingSwap(me, players, now) != null) {
    return SwapBlock.iAmBusy;
  }
  if (other == null || !other.connected) return SwapBlock.notConnected;
  if (other.team == mine.team) return SwapBlock.sameTeam;
  final targetOut = other.swapTo != null && swapFresh(other.swapAt, now);
  final targetAsked = players.any(
    (p) =>
        p.uid != me &&
        p.connected &&
        p.swapTo == target &&
        swapFresh(p.swapAt, now),
  );
  if (targetOut || targetAsked) return SwapBlock.targetBusy;
  return SwapBlock.ok;
}

/// 요청한 사람이 지금 해야 할 일.
enum RequesterStep {
  /// 요청 없음.
  idle,

  /// 응답을 기다린다.
  waiting,

  /// 상대가 수락했다: 내 팀을 상대 팀의 반대로 바꾸고 요청을 지운다.
  moveNow,

  /// 상대가 거절했다: 요청을 지운다.
  declined,

  /// 시간이 지났다: 요청을 지운다.
  expired,

  /// 상대가 나갔거나 이미 같은 팀이 됐다(다른 요청이 먼저 처리됨): 요청을 지운다.
  invalid,
}

RequesterStep requesterStep(String me, List<SwapPlayer> players, int now) {
  final mine = _find(players, me);
  if (mine == null || mine.swapTo == null) return RequesterStep.idle;
  final target = _find(players, mine.swapTo);
  if (target == null || !target.connected) return RequesterStep.invalid;
  // 수락은 시간 제한보다 먼저 본다(마지막 순간에 수락했어도 인정).
  if (target.swapAccepted == me) return RequesterStep.moveNow;
  if (target.swapDeclined == me) return RequesterStep.declined;
  if (!swapFresh(mine.swapAt, now)) return RequesterStep.expired;
  if (target.team == mine.team) return RequesterStep.invalid;
  return RequesterStep.waiting;
}

/// 수락·거절을 한 사람이, 요청자가 요청을 지운 뒤 자기 표시(`swapAccepted`·`swapDeclined`)를 지울 때인지.
bool shouldClearSwapMarks(String me, List<SwapPlayer> players) {
  final mine = _find(players, me);
  if (mine == null) return false;
  for (final uid in [mine.swapAccepted, mine.swapDeclined]) {
    if (uid == null) continue;
    final requester = _find(players, uid);
    if (requester == null || !requester.connected || requester.swapTo != me) {
      return true;
    }
  }
  return false;
}

/// 처리 중인 자리 바꾸기가 있는지(있으면 방장이 시작할 수 없다).
bool swapPending(List<SwapPlayer> players, int now) => players.any(
  (p) =>
      p.connected &&
      ((p.swapTo != null && swapFresh(p.swapAt, now)) ||
          p.swapAccepted != null),
);

// ------------------------------------------------------------ 게임 안 (2단계)

/// 아군에게는 피해·맞힘이 없고 총알이 통과한다.
bool canHit({required String shooterTeam, required String targetTeam}) =>
    shooterTeam != targetTeam;

/// 매치 결과를 meta에 기록하는 사람: 방장이 연결돼 있으면 방장, 아니면 연결된 사람 중 uid가
/// 가장 작은 사람(방장이 나가도 매치가 끝난다). 연결된 사람이 없으면 null.
String? finisherUid({
  required String hostUid,
  required Iterable<({String uid, bool connected})> players,
}) {
  final alive = [
    for (final p in players)
      if (p.connected) p.uid,
  ];
  if (alive.isEmpty) return null;
  if (alive.contains(hostUid)) return hostUid;
  alive.sort();
  return alive.first;
}
