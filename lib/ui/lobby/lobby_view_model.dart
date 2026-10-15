import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/room.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/room_repository.dart';
import '../../rules/balance.dart';
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

  bool get canStart =>
      isHost && players.length == RoomRepository.maxPlayers && !started;

  /// [error]는 넘기지 않으면 지워진다.
  LobbyState copyWith({
    String? uid,
    String? code,
    bool? isHost,
    List<RoomPlayer>? players,
    bool? busy,
    String? error,
    bool? started,
  }) => LobbyState(
    uid: uid ?? this.uid,
    code: code ?? this.code,
    isHost: isHost ?? this.isHost,
    players: players ?? this.players,
    busy: busy ?? this.busy,
    error: error,
    started: started ?? this.started,
  );
}

final lobbyProvider = NotifierProvider<LobbyViewModel, LobbyState>(
  LobbyViewModel.new,
);

class LobbyViewModel extends Notifier<LobbyState> {
  final _subs = <StreamSubscription<Object?>>[];

  AuthRepository get _auth => ref.read(authRepositoryProvider);
  RoomRepository get rooms => ref.read(roomRepositoryProvider);

  @override
  LobbyState build() {
    ref.onDispose(_cancel);
    return const LobbyState();
  }

  Future<void> createRoom() => _enter((uid, name) async {
    final code = await rooms.createRoom(
      uid: uid,
      name: name,
      character: myCharacter(ref),
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
      state = LobbyState(uid: uid, code: room.code, isHost: room.host);
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
      rooms
          .players(code)
          .listen(
            (ps) => state = state.copyWith(
              players: [
                for (final p in ps)
                  if (p.connected) p,
              ],
            ),
          ),
      rooms.meta(code).listen((m) {
        if (m?.status == RoomMeta.playing) {
          state = state.copyWith(started: true);
        }
      }),
    ]);
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
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
  }
}
