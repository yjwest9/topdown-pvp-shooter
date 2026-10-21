import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/room_teams.dart';

SwapPlayer p(
  String uid,
  String team, {
  bool connected = true,
  String? swapTo,
  int? swapAt,
  String? swapAccepted,
  String? swapDeclined,
}) => (
  uid: uid,
  team: team,
  connected: connected,
  swapTo: swapTo,
  swapAt: swapAt,
  swapAccepted: swapAccepted,
  swapDeclined: swapDeclined,
);

/// 각자 자기 노드만 바꾸는 로비를 흉내 낸다(DB 대신 맵).
class Lobby {
  Lobby(List<SwapPlayer> list) : _p = {for (final x in list) x.uid: x};
  final Map<String, SwapPlayer> _p;
  int now = 100000;

  List<SwapPlayer> get all => _p.values.toList();
  SwapPlayer of(String uid) => _p[uid]!;
  String teamOf(String uid) => _p[uid]!.team;

  void _set(
    String uid, {
    String? team,
    Object? swapTo = _keep,
    Object? swapAt = _keep,
    Object? swapAccepted = _keep,
    Object? swapDeclined = _keep,
  }) {
    final o = _p[uid]!;
    _p[uid] = p(
      uid,
      team ?? o.team,
      connected: o.connected,
      swapTo: identical(swapTo, _keep) ? o.swapTo : swapTo as String?,
      swapAt: identical(swapAt, _keep) ? o.swapAt : swapAt as int?,
      swapAccepted: identical(swapAccepted, _keep)
          ? o.swapAccepted
          : swapAccepted as String?,
      swapDeclined: identical(swapDeclined, _keep)
          ? o.swapDeclined
          : swapDeclined as String?,
    );
  }

  void request(String me, String target) {
    expect(
      canRequestSwap(me: me, target: target, players: all, now: now),
      SwapBlock.ok,
    );
    _set(me, swapTo: target, swapAt: now);
  }

  void cancel(String me) => _set(me, swapTo: null, swapAt: null);

  String? incoming(String me) => incomingSwap(me, all, now)?.uid;

  void accept(String me) {
    final req = incomingSwap(me, all, now)!;
    _set(me, team: req.team, swapAccepted: req.uid);
  }

  void decline(String me) {
    final req = incomingSwap(me, all, now)!;
    _set(me, swapDeclined: req.uid);
  }

  /// 모두가 자기 차례 처리를 한 번씩(요청자 단계 + 대상 정리). 변화가 없을 때까지 반복.
  void settle() {
    for (var i = 0; i < 6; i++) {
      for (final id in _p.keys.toList()) {
        final step = requesterStep(id, all, now);
        switch (step) {
          case RequesterStep.moveNow:
            final target = of(of(id).swapTo!);
            _set(id, team: otherTeam(target.team), swapTo: null, swapAt: null);
          case RequesterStep.declined ||
              RequesterStep.expired ||
              RequesterStep.invalid:
            _set(id, swapTo: null, swapAt: null);
          case RequesterStep.idle || RequesterStep.waiting:
            break;
        }
        if (shouldClearSwapMarks(id, all)) {
          _set(id, swapAccepted: null, swapDeclined: null);
        }
      }
    }
  }
}

const _keep = Object();

void main() {
  group('teamSize', () {
    test('1 or 2; missing or unknown means 1 (old rooms, old apps)', () {
      expect(teamSizeOf(null), 1);
      expect(teamSizeOf(1), 1);
      expect(teamSizeOf(2), 2);
      expect(teamSizeOf(3), 1);
      expect(teamSizeOf('2'), 1);
    });

    test('room capacity = teamSize × 2', () {
      expect(roomFull(count: 1, teamSize: 1), false);
      expect(roomFull(count: 2, teamSize: 1), true);
      expect(roomFull(count: 3, teamSize: 2), false);
      expect(roomFull(count: 4, teamSize: 2), true);
    });
  });

  group('assignTeam: the team with fewer players, A on a tie', () {
    test('1v1: host A, then the joiner goes to B', () {
      expect(assignTeam(a: 0, b: 0), 'A');
      expect(assignTeam(a: 1, b: 0), 'B');
    });

    test('2v2: the joiners fill A2 B2', () {
      final order = <String>[];
      var a = 0, b = 0;
      for (var i = 0; i < 4; i++) {
        final t = assignTeam(a: a, b: b);
        order.add(t);
        t == 'A' ? a++ : b++;
      }
      expect(order, ['A', 'B', 'A', 'B']);
    });

    test('someone left: the team that lost a player gets the next one', () {
      expect(assignTeam(a: 1, b: 2), 'A');
      expect(assignTeam(a: 2, b: 1), 'B');
    });
  });

  group('canMoveTo: only an empty seat on the other team', () {
    test('other team with a vacancy → yes', () {
      expect(canMoveTo('B', myTeam: 'A', targetCount: 1, teamSize: 2), true);
    });

    test('full other team, or my own team → no', () {
      expect(canMoveTo('B', myTeam: 'A', targetCount: 2, teamSize: 2), false);
      expect(canMoveTo('A', myTeam: 'A', targetCount: 0, teamSize: 2), false);
    });

    test('1v1: the other seat is taken → no, free → yes', () {
      expect(canMoveTo('B', myTeam: 'A', targetCount: 1, teamSize: 1), false);
      expect(canMoveTo('B', myTeam: 'A', targetCount: 0, teamSize: 1), true);
    });
  });

  group('canStartRoom', () {
    test('both teams exactly teamSize and no swap in progress', () {
      expect(canStartRoom(a: 2, b: 2, teamSize: 2, swapPending: false), true);
      expect(canStartRoom(a: 1, b: 1, teamSize: 1, swapPending: false), true);
    });

    test('lopsided, short, or swap pending → no', () {
      expect(canStartRoom(a: 3, b: 1, teamSize: 2, swapPending: false), false);
      expect(canStartRoom(a: 2, b: 1, teamSize: 2, swapPending: false), false);
      expect(canStartRoom(a: 2, b: 2, teamSize: 2, swapPending: true), false);
      expect(canStartRoom(a: 1, b: 0, teamSize: 1, swapPending: false), false);
    });
  });

  group('swap: request → accept / decline / timeout / cancel', () {
    Lobby four() =>
        Lobby([p('a1', 'A'), p('a2', 'A'), p('b1', 'B'), p('b2', 'B')]);

    test('accept: the two switch teams, marks are cleaned up', () {
      final l = four()..request('a1', 'b1');
      expect(l.incoming('b1'), 'a1');
      expect(l.incoming('a2'), isNull); // 남에겐 안 보인다
      l.accept('b1');
      // 수락 직후 b1은 이미 A팀, 요청자가 아직 안 옮겼다.
      expect(l.teamOf('b1'), 'A');
      l.settle();
      expect((l.teamOf('a1'), l.teamOf('b1')), ('B', 'A'));
      expect((l.teamOf('a2'), l.teamOf('b2')), ('A', 'B'));
      for (final id in ['a1', 'a2', 'b1', 'b2']) {
        final x = l.of(id);
        expect(
          (x.swapTo, x.swapAt, x.swapAccepted, x.swapDeclined),
          (null, null, null, null),
          reason: id,
        );
      }
      expect(swapPending(l.all, l.now), false);
    });

    test(
      'decline: nothing moves, the requester is told, marks are cleaned',
      () {
        final l = four()..request('a1', 'b1');
        l.decline('b1');
        expect(requesterStep('a1', l.all, l.now), RequesterStep.declined);
        l.settle();
        expect((l.teamOf('a1'), l.teamOf('b1')), ('A', 'B'));
        expect(l.of('a1').swapTo, isNull);
        expect(l.of('b1').swapDeclined, isNull);
      },
    );

    test('waiting until the time limit, then auto-cancel (10 s)', () {
      final l = four()..request('a1', 'b1');
      l.now += swapTimeoutMs - 1;
      expect(requesterStep('a1', l.all, l.now), RequesterStep.waiting);
      expect(l.incoming('b1'), 'a1');
      l.now += 1;
      expect(requesterStep('a1', l.all, l.now), RequesterStep.expired);
      expect(l.incoming('b1'), isNull); // 대상의 창도 닫힌다
      l.settle();
      expect(l.of('a1').swapTo, isNull);
      expect((l.teamOf('a1'), l.teamOf('b1')), ('A', 'B'));
    });

    test('the requester can cancel: the request disappears for the target', () {
      final l = four()..request('a1', 'b1');
      l.cancel('a1');
      expect(l.incoming('b1'), isNull);
      expect(requesterStep('a1', l.all, l.now), RequesterStep.idle);
    });

    test('one request at a time: I cannot ask twice or while asked', () {
      final l = four()..request('a1', 'b1');
      expect(
        canRequestSwap(me: 'a1', target: 'b2', players: l.all, now: l.now),
        SwapBlock.iAmBusy,
      );
      // b2는 a2에게 요청할 수 있지만, 이미 요청받은 b1에게 a2가 또 요청은 못 한다.
      expect(
        canRequestSwap(me: 'a2', target: 'b1', players: l.all, now: l.now),
        SwapBlock.targetBusy,
      );
      // 요청받은 사람이 자기도 요청하려 하면 막는다(대기 중이니 응답이 먼저).
      expect(
        canRequestSwap(me: 'b1', target: 'a2', players: l.all, now: l.now),
        SwapBlock.iAmBusy,
      );
    });

    test('same team, or a disconnected target → cannot request', () {
      final l = Lobby([
        p('a1', 'A'),
        p('a2', 'A'),
        p('b1', 'B', connected: false),
      ]);
      expect(
        canRequestSwap(me: 'a1', target: 'a2', players: l.all, now: l.now),
        SwapBlock.sameTeam,
      );
      expect(
        canRequestSwap(me: 'a1', target: 'b1', players: l.all, now: l.now),
        SwapBlock.notConnected,
      );
    });

    test('an expired request does not block a new one', () {
      final l = four()..request('a1', 'b1');
      l.now += swapTimeoutMs;
      expect(
        canRequestSwap(me: 'a2', target: 'b1', players: l.all, now: l.now),
        SwapBlock.ok,
      );
    });

    test('two requests at the same moment: one is answered, the other '
        'becomes invalid and cancels itself', () {
      // a1과 a2가 동시에 b1에게 요청(둘 다 막히기 전에 썼다).
      final l = four();
      l._set('a1', swapTo: 'b1', swapAt: l.now);
      l._set('a2', swapTo: 'b1', swapAt: l.now + 50);
      expect(l.incoming('b1'), 'a1'); // 먼저 온 것
      l.accept('b1');
      l.settle();
      // a1 ↔ b1이 바뀜. a2의 요청은 b1이 이제 같은 팀(A)이라 무효 → 스스로 취소.
      expect((l.teamOf('a1'), l.teamOf('b1')), ('B', 'A'));
      expect(l.teamOf('a2'), 'A');
      expect(l.of('a2').swapTo, isNull);
      expect(swapPending(l.all, l.now), false);
    });

    test('two requests crossing each other: the earlier one wins', () {
      // a1 → b1 와 b1 → a1 이 동시에.
      final l = four();
      l._set('a1', swapTo: 'b1', swapAt: l.now);
      l._set('b1', swapTo: 'a1', swapAt: l.now + 30);
      // 서로의 요청이 있으면 먼저 쓴 쪽(a1)의 요청만 유효하다.
      expect(l.incoming('b1'), 'a1');
      expect(l.incoming('a1'), isNull);
    });

    test('the requester left before answering → the request is void', () {
      final l = Lobby([
        p('a1', 'A', connected: false, swapTo: 'b1', swapAt: 100000),
        p('b1', 'B'),
      ]);
      expect(incomingSwap('b1', l.all, l.now), isNull);
    });

    test('swapPending: a fresh request or an unfinished accept', () {
      final l = four();
      expect(swapPending(l.all, l.now), false);
      l.request('a1', 'b1');
      expect(swapPending(l.all, l.now), true);
      l.accept('b1');
      expect(swapPending(l.all, l.now), true); // 수락됐지만 요청자가 아직
      l.settle();
      expect(swapPending(l.all, l.now), false);
    });
  });

  group('in-game (2v2 stage 2)', () {
    test('friendly fire: allies are never hit, enemies are', () {
      expect(canHit(shooterTeam: 'A', targetTeam: 'A'), false);
      expect(canHit(shooterTeam: 'A', targetTeam: 'B'), true);
      expect(canHit(shooterTeam: 'B', targetTeam: 'A'), true);
    });

    test('finisher: the host while connected, else the smallest uid', () {
      ({String uid, bool connected}) u(String id, {bool on = true}) =>
          (uid: id, connected: on);
      expect(finisherUid(hostUid: 'h', players: [u('b'), u('h'), u('c')]), 'h');
      // 방장이 나갔다: 연결된 사람 중 uid가 가장 작은 사람.
      expect(
        finisherUid(
          hostUid: 'h',
          players: [u('h', on: false), u('d'), u('b'), u('c')],
        ),
        'b',
      );
      expect(
        finisherUid(
          hostUid: 'h',
          players: [u('h', on: false), u('b', on: false), u('c')],
        ),
        'c',
      );
      expect(finisherUid(hostUid: 'h', players: [u('h', on: false)]), isNull);
    });

    test('1v1: with the host connected nothing changes', () {
      ({String uid, bool connected}) u(String id) => (uid: id, connected: true);
      expect(finisherUid(hostUid: 'z', players: [u('a'), u('z')]), 'z');
    });
  });
}
