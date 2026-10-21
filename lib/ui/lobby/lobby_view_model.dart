import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/room.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/room_repository.dart';
import '../../rules/balance.dart';
import '../../rules/room_teams.dart';
import '../format.dart';

class LobbyState {
  const LobbyState({
    this.uid,
    this.code,
    this.isHost = false,
    this.players = const [],
    this.busy = false,
    this.error,
    this.started = false,
    this.map = 'duel',
    this.teamSize = 1,
    this.now = 0,
    this.notice,
    this.noticeSeq = 0,
  });

  final String? uid;

  /// null = 메뉴, 있으면 대기실.
  final String? code;
  final bool isHost;

  /// 접속 중인 참가자.
  final List<RoomPlayer> players;
  final bool busy;
  final String? error;

  /// 방장이 시작함 → 게임 화면으로.
  final bool started;

  /// 방 만들기 전엔 방장이 고른 맵, 대기실에선 방 meta의 맵. 둘 다 id(`rules/map_select.dart`).
  final String map;

  /// 한 팀 인원(1 또는 2). 방 만들기 전엔 방장이 고른 값, 대기실에선 방 meta 값.
  final int teamSize;

  /// 서버 시간 추정(ms). 자리 바꾸기 10초 계산용(1초마다 갱신).
  final int now;

  /// 자리 바꾸기 결과 안내(거절·시간 초과 등). [noticeSeq]가 바뀔 때마다 한 번 보여 준다.
  final String? notice;
  final int noticeSeq;

  List<RoomPlayer> teamPlayers(String team) => [
    for (final p in players)
      if (p.team == team) p,
  ];

  List<SwapPlayer> get _swaps => [for (final p in players) p.swap];

  RoomPlayer? get me {
    for (final p in players) {
      if (p.uid == uid) return p;
    }
    return null;
  }

  String get myTeam => me?.team ?? teamAId;

  /// 같은 팀 사람 중 내 순서(uid 순). 2대2 시작 스폰이 겹치지 않게.
  int get allyIndex {
    final ids = [for (final p in teamPlayers(myTeam)) p.uid]..sort();
    final i = ids.indexOf(uid ?? '');
    return i < 0 ? 0 : i;
  }

  /// 처리 중인 자리 바꾸기가 있다.
  bool get swapInProgress => swapPending(_swaps, now);

  /// 상대 팀에 빈자리가 있어 "이 팀으로" 옮길 수 있다(자리 바꾸기 중이면 안 됨).
  bool get canMove =>
      uid != null &&
      !swapInProgress &&
      canMoveTo(
        otherTeam(myTeam),
        myTeam: myTeam,
        targetCount: teamPlayers(otherTeam(myTeam)).length,
        teamSize: teamSize,
      );

  /// [target]에게 자리 바꾸기를 요청할 수 있는가(아니면 이유).
  SwapBlock swapBlock(String target) => uid == null
      ? SwapBlock.notConnected
      : canRequestSwap(me: uid!, target: target, players: _swaps, now: now);

  /// 나에게 온 자리 바꾸기 요청(응답 대기). 없으면 null.
  RoomPlayer? get incoming {
    final r = uid == null ? null : incomingSwap(uid!, _swaps, now);
    if (r == null) return null;
    for (final p in players) {
      if (p.uid == r.uid) return p;
    }
    return null;
  }

  /// 내가 보낸 요청의 상대(응답 대기 중). 없으면 null.
  RoomPlayer? get outgoing {
    final m = me;
    if (m == null || m.swapTo == null || !swapFresh(m.swapAt, now)) return null;
    for (final p in players) {
      if (p.uid == m.swapTo) return p;
    }
    return null;
  }

  /// 방장이 시작할 수 있다(두 팀이 모두 teamSize명이고 처리 중인 자리 바꾸기가 없을 때).
  bool get canStart =>
      isHost &&
      !started &&
      canStartRoom(
        a: teamPlayers(teamAId).length,
        b: teamPlayers(teamBId).length,
        teamSize: teamSize,
        swapPending: swapInProgress,
      );

  /// [error]는 넘기지 않으면 지워진다.
  LobbyState copyWith({
    String? uid,
    String? code,
    bool? isHost,
    List<RoomPlayer>? players,
    bool? busy,
    String? error,
    bool? started,
    String? map,
    int? teamSize,
    int? now,
    String? notice,
    int? noticeSeq,
  }) => LobbyState(
    uid: uid ?? this.uid,
    code: code ?? this.code,
    isHost: isHost ?? this.isHost,
    players: players ?? this.players,
    busy: busy ?? this.busy,
    error: error,
    started: started ?? this.started,
    map: map ?? this.map,
    teamSize: teamSize ?? this.teamSize,
    now: now ?? this.now,
    notice: notice ?? this.notice,
    noticeSeq: noticeSeq ?? this.noticeSeq,
  );
}

final lobbyProvider = NotifierProvider<LobbyViewModel, LobbyState>(
  LobbyViewModel.new,
);

class LobbyViewModel extends Notifier<LobbyState> {
  final _subs = <StreamSubscription<Object?>>[];
  Timer? _tick;
  bool _reacting = false;

  AuthRepository get _auth => ref.read(authRepositoryProvider);
  RoomRepository get rooms => ref.read(roomRepositoryProvider);

  @override
  LobbyState build() {
    ref.onDispose(_cancel);
    return const LobbyState();
  }

  /// 방 만들기 전에 방장이 맵을 고른다(2대2는 outpost 고정).
  void selectMap(String id) {
    if (state.teamSize == 2) return;
    state = state.copyWith(map: id);
  }

  /// 방 만들기 전에 방장이 인원을 고른다. 2대2는 맵이 outpost로 고정(decisions 12장).
  void selectTeamSize(int n) => state = state.copyWith(
    teamSize: n == 2 ? 2 : 1,
    map: n == 2 ? 'outpost' : null,
  );

  Future<void> createRoom() => _enter((uid, name) async {
    final code = await rooms.createRoom(
      uid: uid,
      name: name,
      character: myCharacter(ref),
      map: state.map,
      teamSize: state.teamSize,
    );
    return (code: code, host: true);
  });

  Future<void> joinRoom(String code) {
    if (!RegExp(r'^\d{4}$').hasMatch(code)) {
      state = state.copyWith(error: '4자리 숫자를 입력하세요.');
      return Future.value();
    }
    return _enter((uid, name) async {
      await rooms.joinRoom(
        code,
        uid: uid,
        name: name,
        character: myCharacter(ref),
      );
      return (code: code, host: false);
    });
  }

  Future<void> _enter(
    Future<({String code, bool host})> Function(String uid, String name) go,
  ) async {
    if (state.busy) return;
    state = state.copyWith(busy: true);
    try {
      // DB에 연결이 안 돼 있으면 기다리지 않고 바로 알린다(재연결을 한 번 시도, decisions 13장).
      if (!await rooms.connection.ensureConnected()) {
        state = state.copyWith(busy: false, error: connectionErrorText);
        return;
      }
      final uid = await _auth.signIn().timeout(requestTimeout);
      final room = await go(uid, myNickname(ref)).timeout(requestTimeout);
      state = LobbyState(
        uid: uid,
        code: room.code,
        isHost: room.host,
        map: state.map,
        teamSize: state.teamSize,
      );
      _watch(room.code);
    } on RoomException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
    } catch (e) {
      debugPrint('방 연결 실패: $e');
      state = state.copyWith(busy: false, error: connectionErrorText);
    }
  }

  void _watch(String code) {
    _subs.addAll([
      rooms.players(code).listen((ps) {
        state = state.copyWith(
          players: [
            for (final p in ps)
              if (p.connected) p,
          ],
        );
        unawaited(tick());
      }),
      rooms.meta(code).listen((m) {
        if (m == null) return;
        state = state.copyWith(
          map: m.map,
          teamSize: m.teamSize,
          started: m.status == RoomMeta.playing ? true : null,
        );
      }),
    ]);
    _tick?.cancel();
    _tick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(tick()),
    );
  }

  /// 서버 시간을 갱신하고 내 자리 바꾸기 차례를 처리한다(요청자: 수락 확인·시간 초과, 대상: 표시 정리).
  /// 1초마다, 참가자가 바뀔 때마다 돈다.
  Future<void> tick() async {
    final code = state.code, uid = state.uid;
    if (code == null || uid == null || _reacting) return;
    _reacting = true;
    try {
      final now = await rooms.serverNow();
      if (state.code != code) return;
      state = state.copyWith(now: now);
      final swaps = [for (final p in state.players) p.swap];
      final step = requesterStep(uid, swaps, now);
      switch (step) {
        case RequesterStep.moveNow:
          final target = swaps.firstWhere((p) => p.uid == state.me!.swapTo);
          await rooms.finishSwap(code, uid, otherTeam(target.team));
          _notify('자리를 바꿨습니다');
        case RequesterStep.declined:
          await rooms.clearSwapRequest(code, uid);
          _notify('상대가 자리 바꾸기를 거절했습니다');
        case RequesterStep.expired:
          await rooms.clearSwapRequest(code, uid);
          _notify('응답이 없어 자리 바꾸기가 취소되었습니다');
        case RequesterStep.invalid:
          await rooms.clearSwapRequest(code, uid);
          _notify('자리 바꾸기를 할 수 없게 되어 취소되었습니다');
        case RequesterStep.idle || RequesterStep.waiting:
          break;
      }
      if (shouldClearSwapMarks(uid, swaps)) {
        await rooms.clearSwapMarks(code, uid);
      }
    } catch (e) {
      debugPrint('자리 바꾸기 처리 실패: $e');
    } finally {
      _reacting = false;
    }
  }

  void _notify(String text) =>
      state = state.copyWith(notice: text, noticeSeq: state.noticeSeq + 1);

  /// 상대 팀에 빈자리가 있을 때 "이 팀으로".
  Future<void> moveToOtherTeam() async {
    final code = state.code, uid = state.uid;
    if (code == null || uid == null || !state.canMove) return;
    await rooms.moveTeam(code, uid, otherTeam(state.myTeam));
  }

  /// "자리 바꾸기" 요청.
  Future<void> requestSwap(String target) async {
    final code = state.code, uid = state.uid;
    if (code == null || uid == null) return;
    if (state.swapBlock(target) != SwapBlock.ok) return;
    await rooms.requestSwap(code, uid, target);
  }

  /// 요청한 사람이 취소.
  Future<void> cancelSwap() async {
    final code = state.code, uid = state.uid;
    if (code == null || uid == null) return;
    await rooms.clearSwapRequest(code, uid);
  }

  /// 받은 요청 수락: 내 팀을 요청자 팀으로 바꾸고 알린다. 요청자가 보고 자기 팀을 바꾼다.
  Future<void> acceptSwap() async {
    final code = state.code, uid = state.uid, req = state.incoming;
    if (code == null || uid == null || req == null) return;
    await rooms.acceptSwap(code, uid, requester: req.uid, team: req.team);
  }

  Future<void> declineSwap() async {
    final code = state.code, uid = state.uid, req = state.incoming;
    if (code == null || uid == null || req == null) return;
    await rooms.declineSwap(code, uid, req.uid);
  }

  Future<void> start() async {
    if (state.canStart) {
      await rooms.start(state.code!, durationMs: matchDurationMs);
    }
  }

  /// 대기실에서 나가기.
  Future<void> leaveRoom() async {
    final code = state.code;
    final uid = state.uid;
    backToMenu();
    if (code != null && uid != null) await rooms.leave(code, uid);
  }

  /// 게임이 끝나 돌아왔을 때. 게임 화면이 이미 방을 나갔다.
  void backToMenu() {
    _cancel();
    state = const LobbyState();
  }

  void _cancel() {
    _tick?.cancel();
    _tick = null;
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
  }
}
