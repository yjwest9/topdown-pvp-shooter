import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/room.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/room_repository.dart';
import '../../rules/balance.dart';
import '../../rules/matchmaking.dart';
import '../format.dart';

class MatchmakingState {
  const MatchmakingState({
    this.elapsed = Duration.zero,
    this.uid,
    this.roomId,
    this.isHost = false,
    this.opponent,
    this.countdown = quickMatchCountdown,
    this.started = false,
    this.error,
  });

  /// 찾기 시작한 뒤 지난 시간.
  final Duration elapsed;
  final String? uid;

  /// 매칭된 방. 찾는 중엔 null.
  final String? roomId;
  final bool isHost;

  /// 상대 닉네임. 있으면 찾음.
  final String? opponent;

  /// 찾은 뒤 시작까지 남은 초.
  final int countdown;

  /// 방장이 시작함 → 게임 화면으로.
  final bool started;
  final String? error;

  bool get found => opponent != null;
  bool get offerBot => !found && elapsed >= quickMatchBotOffer;

  MatchmakingState copyWith({
    Duration? elapsed,
    String? uid,
    String? roomId,
    bool? isHost,
    String? opponent,
    int? countdown,
    bool? started,
    String? error,
  }) => MatchmakingState(
    elapsed: elapsed ?? this.elapsed,
    uid: uid ?? this.uid,
    roomId: roomId ?? this.roomId,
    isHost: isHost ?? this.isHost,
    opponent: opponent ?? this.opponent,
    countdown: countdown ?? this.countdown,
    started: started ?? this.started,
    error: error ?? this.error,
  );
}

/// 화면이 열리면 바로 찾기 시작하고, 화면이 닫히면(취소·뒤로 가기) 대기석과 내 방을 치운다.
final matchmakingProvider =
    NotifierProvider.autoDispose<MatchmakingViewModel, MatchmakingState>(
      MatchmakingViewModel.new,
    );

/// 빠른 대전 1대1 (decisions 13장 매칭).
class MatchmakingViewModel extends Notifier<MatchmakingState> {
  late RoomRepository rooms;
  late AuthRepository _auth;

  final _subs = <StreamSubscription<Object?>>[];
  Timer? _clock;
  Timer? _beat;
  Timer? _count;

  /// 누가 내 자리를 잡은 뒤 상대가 안 오면 다시 찾기.
  Timer? _noShow;

  /// 내 방 참가자(방을 새로 만들면 바꿔 단다).
  StreamSubscription<Object?>? _roomSub;

  String? _uid;
  String _name = '';

  /// 내가 만든 방(대기석에 앉으면 이 방으로 상대가 온다).
  String? _myRoom;

  /// 대기석에 내가 앉아 있다.
  bool _sitting = false;
  bool _attempting = false;
  bool _closed = false;

  /// 상대를 찾음. 화면이 닫힌 뒤에도 읽으므로 state 대신 따로 둔다.
  bool _matched = false;

  @override
  MatchmakingState build() {
    rooms = ref.read(roomRepositoryProvider);
    _auth = ref.read(authRepositoryProvider);
    ref.onDispose(() => unawaited(cancel()));
    Future.microtask(_start);
    return const MatchmakingState();
  }

  Future<void> _start() async {
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(
        elapsed: state.elapsed + const Duration(seconds: 1),
      );
    });
    try {
      // DB에 연결이 안 돼 있으면 기다리지 않고 바로 알린다(재연결을 한 번 시도, decisions 13장).
      if (!await rooms.connection.ensureConnected()) {
        _stopTimers();
        state = state.copyWith(error: connectionErrorText);
        return;
      }
      final uid = _uid = await _auth.signIn().timeout(requestTimeout);
      _name = myNickname(ref);
      if (_closed) return;
      final room = _myRoom = await rooms
          .createQuickRoom(uid: uid, name: _name, character: myCharacter(ref))
          .timeout(requestTimeout);
      state = state.copyWith(uid: uid);
      _subs.add(rooms.slot().listen(_onSlot));
      _roomSub = rooms.players(room).listen(_onMyRoomPlayers);
      await _attempt();
    } catch (e) {
      _stopTimers();
      debugPrint('빠른 대전 연결 실패: $e');
      state = state.copyWith(error: connectionErrorText);
    }
  }

  /// 대기석 판정을 한 번(재시도면 될 때까지) 한다.
  Future<void> _attempt() async {
    if (_attempting) return;
    _attempting = true;
    try {
      final uid = _uid!;
      while (!_closed && !_matched) {
        final now = await rooms.serverNow();
        var action = QuickMatchAction.retry;
        final slot = await rooms.claimSlot((cur) {
          action = decideQuickMatch(
            cur == null ? null : (uid: cur.uid, t: cur.t, takenBy: cur.takenBy),
            uid,
            now,
          );
          return switch (action) {
            QuickMatchAction.claim || QuickMatchAction.wait => WaitingSlot(
              uid: uid,
              roomId: _myRoom!,
              name: _name,
              t: now,
            ),
            QuickMatchAction.take => WaitingSlot(
              uid: cur!.uid,
              roomId: cur.roomId,
              name: cur.name,
              t: cur.t,
              takenBy: uid,
            ),
            QuickMatchAction.retry => null,
          };
        });
        switch (action) {
          case QuickMatchAction.claim || QuickMatchAction.wait:
            if (_closed) {
              await rooms.leaveSlot(uid);
              return;
            }
            _sitting = true;
            await rooms.removeSlotOnDisconnect();
            _beat ??= Timer.periodic(
              quickMatchHeartbeat,
              (_) => unawaited(_heartbeat()),
            );
            return;
          case QuickMatchAction.take:
            if (_closed) return;
            try {
              await rooms.joinRoom(
                slot!.roomId,
                uid: uid,
                name: _name,
                character: myCharacter(ref),
              );
            } on RoomException {
              continue; // 방장이 막 취소함 → 다시 판정
            }
            await rooms.deleteRoom(_myRoom!);
            if (_closed) return;
            _found(slot.roomId, opponent: slot.name, host: false);
            return;
          case QuickMatchAction.retry:
            await Future<void>.delayed(quickMatchRetry);
        }
      }
    } finally {
      _attempting = false;
    }
  }

  Future<void> _heartbeat() async =>
      rooms.heartbeat(_uid!, await rooms.serverNow());

  void _onSlot(WaitingSlot? s) {
    if (!_sitting) return;
    if (s != null && s.uid == _uid) {
      if (s.takenBy != null) {
        // 누가 잡았다 → 대기석을 비우고 그 사람이 방에 들어오길 기다린다.
        _sitting = false;
        _stopBeat();
        unawaited(rooms.leaveSlot(_uid!));
        _noShow = Timer(
          quickMatchTakenTimeout,
          () => unawaited(_searchAgain()),
        );
      }
      return;
    }
    // 내 자리를 잃음(오래돼서 남이 앉음 등) → 다시 판정.
    _sitting = false;
    _stopBeat();
    unawaited(_attempt());
  }

  /// 잡은 사람이 안 왔다(취소·앱 종료) → 내 방을 지우고 새 방으로 다시 찾는다.
  /// 늦게 온 사람은 없는 방이라 입장에 실패하고 스스로 다시 찾는다.
  Future<void> _searchAgain() async {
    if (_matched || _closed) return;
    final old = _myRoom!;
    unawaited(_roomSub?.cancel());
    await rooms.deleteRoom(old);
    final room = _myRoom = await rooms.createQuickRoom(
      uid: _uid!,
      name: _name,
      character: myCharacter(ref),
    );
    if (_closed) return rooms.deleteRoom(room);
    _roomSub = rooms.players(room).listen(_onMyRoomPlayers);
    await _attempt();
  }

  void _onMyRoomPlayers(List<RoomPlayer> ps) {
    if (_matched || _closed) return;
    for (final p in ps) {
      if (p.connected && p.uid != _uid) {
        _sitting = false;
        _stopBeat();
        unawaited(rooms.leaveSlot(_uid!));
        _found(_myRoom!, opponent: p.name, host: true);
        return;
      }
    }
  }

  /// 상대를 찾음: 카운트다운 뒤 방장이 시작한다.
  void _found(String roomId, {required String opponent, required bool host}) {
    if (_matched) return;
    _matched = true;
    _clock?.cancel();
    _noShow?.cancel();
    state = state.copyWith(roomId: roomId, isHost: host, opponent: opponent);
    unawaited(rooms.keepRoom(roomId, _uid!));
    _subs.add(
      rooms.meta(roomId).listen((m) {
        if (m?.status == RoomMeta.playing && !state.started) {
          state = state.copyWith(started: true);
        }
      }),
    );
    _count = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = state.countdown - 1;
      state = state.copyWith(countdown: left);
      if (left > 0) return;
      t.cancel();
      if (host) unawaited(rooms.start(roomId, durationMs: matchDurationMs));
    });
  }

  /// 취소(화면이 닫혀도 불린다). 찾는 중이었으면 대기석과 내 방을 지운다.
  Future<void> cancel() async {
    if (_closed) return;
    _closed = true;
    _stopTimers();
    final uid = _uid;
    final room = _myRoom;
    if (!_matched && uid != null) {
      await rooms.leaveSlot(uid); // 대기석을 보고 있는 동안 지운다
      if (room != null) await rooms.deleteRoom(room);
    }
    for (final s in [..._subs, ?_roomSub]) {
      unawaited(s.cancel());
    }
    _subs.clear();
  }

  void _stopBeat() {
    _beat?.cancel();
    _beat = null;
  }

  void _stopTimers() {
    _clock?.cancel();
    _count?.cancel();
    _noShow?.cancel();
    _stopBeat();
  }
}
