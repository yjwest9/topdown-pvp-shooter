import 'dart:async';

import 'package:flame/components.dart';

import '../../data/models/room.dart';
import '../../data/repositories/room_repository.dart';
import '../../rules/balance.dart';
import '../components/bullet.dart';
import '../components/remote_player.dart';
import '../soldier_game.dart';

/// 1대1 동기화. 내 상태를 초당 [stateSendHz]회 보내고, 상대를 [RemotePlayer]로 그린다.
/// 사격은 연출만(데미지·HP는 다음 작업).
class MatchSync extends Component with HasGameReference<SoldierGame> {
  MatchSync({
    required this.rooms,
    required this.code,
    required this.uid,
    required this.isHost,
    int Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final RoomRepository rooms;
  final String code;
  final String uid;
  final bool isHost;
  final int Function() _clock;

  /// 상대가 나가면 한 번 불린다.
  void Function()? onOpponentLeft;

  /// uid → 상대.
  final remotes = <String, RemotePlayer>{};

  final _subs = <StreamSubscription<Object?>>[];
  final _pendingShots = <NetShot>[];
  int _offset = 0;
  double _sinceSend = 0;
  bool _sawOpponent = false;
  bool _stateInFlight = false;
  int _shotsInFlight = 0;
  static const _maxShotsInFlight = 8;
  bool _left = false;

  /// [leave] 뒤. 화면이 닫히기 전까지 상태를 다시 쓰지 않게.
  bool _closed = false;

  int get serverNow => _clock() + _offset;

  /// 상대를 그리는 시각. 늦게 재생해야 두 스냅샷 사이를 보간할 수 있다.
  int get renderTime => serverNow - interpolationDelayMs;

  @override
  void onMount() {
    _subs.addAll([
      rooms.serverTimeOffset().listen((o) => _offset = o),
      rooms.states(code).listen(_onStates),
      rooms.shots(code).listen((s) {
        if (s.by != uid) _pendingShots.add(s);
      }),
      rooms.players(code).listen(_onPlayers),
    ]);
  }

  void _onStates(Map<String, NetState> states) {
    for (final MapEntry(key: id, value: s) in states.entries) {
      if (id == uid) continue;
      remotes
          .putIfAbsent(id, () {
            final r = RemotePlayer(renderTime: () => renderTime);
            game.world.add(r);
            return r;
          })
          .push(s);
    }
  }

  void _onPlayers(List<RoomPlayer> players) {
    final opponentHere = players.any((p) => p.uid != uid && p.connected);
    if (opponentHere) _sawOpponent = true;
    if (_sawOpponent && !opponentHere && !_left) {
      _left = true;
      onOpponentLeft?.call();
    }
  }

  @override
  void update(double dt) {
    if (_closed) return;
    _sinceSend += dt;
    // 이전 기록이 아직 안 끝났으면 건너뛴다. 서버가 느릴 때 요청이 쌓여
    // 네이티브 스레드가 바닥나 앱이 죽는 걸 막는다(실제로 겪음).
    if (_sinceSend >= 1 / stateSendHz && !_stateInFlight) {
      _sinceSend %= 1 / stateSendHz;
      final p = game.player;
      _stateInFlight = true;
      unawaited(
        rooms
            .sendState(
              code,
              uid,
              NetState(
                x: p.position.x,
                y: p.position.y,
                a: p.angle,
                stance: p.stance.name,
                up: p.lift,
                weapon: p.weapon.weapon.id,
              ),
            )
            .whenComplete(() => _stateInFlight = false),
      );
    }
    _spawnDueShots();
  }

  /// 상대 몸과 같은 시각(renderTime)에 총알이 나가게 맞춘다.
  void _spawnDueShots() {
    final now = renderTime;
    _pendingShots.removeWhere((s) {
      if (s.t > now) return false;
      final shooter = remotes[s.by];
      game.world.add(
        Bullet(
          position: Vector2(s.x, s.y),
          angle: s.a,
          weapon: weapons.firstWhere((w) => w.id == s.weapon),
          shooter:
              shooter?.coverBody ??
              (
                pos: (x: s.x, y: s.y),
                crouching: false,
                airborne: false,
                onCrate: false,
              ),
          hitsTargets: false,
        ),
      );
      return true;
    });
  }

  /// 내가 쏜 총알 한 발씩 기록(샷건은 펠릿마다). 밀려 있으면 버린다(연출용이라).
  void sendShot(Vector2 from, double angle, String weapon) {
    if (_shotsInFlight >= _maxShotsInFlight) return;
    _shotsInFlight++;
    unawaited(
      rooms
          .sendShot(
            code,
            NetShot(by: uid, x: from.x, y: from.y, a: angle, weapon: weapon),
          )
          .whenComplete(() => _shotsInFlight--),
    );
  }

  Future<void> leave() async {
    _left = true;
    _closed = true;
    _cancel();
    await rooms.leave(code, uid);
  }

  void _cancel() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
  }

  @override
  void onRemove() => _cancel();
}
