import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';

import '../../data/models/match_stats.dart';
import '../../data/models/room.dart';
import '../../data/repositories/room_repository.dart';
import '../../rules/balance.dart';
import '../../rules/combat.dart';
import '../../rules/match.dart';
import '../components/bullet.dart';
import '../components/remote_player.dart';
import '../soldier_game.dart';

/// 1대1 동기화와 매치 진행. 내 상태를 초당 [stateSendHz]회 보내고, 상대를 [RemotePlayer]로
/// 그린다. 명중 판정은 쏜 사람(나)이 하고, 체력은 트랜잭션으로 깎는다(decisions 13장).
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

  /// 방장 A(남쪽), 참가자 B(북쪽).
  String get team => isHost ? RoomMeta.teamA : RoomMeta.teamB;

  /// 매치가 끝나면 한 번 불린다. [opponentLeft]면 상대가 나가서 이긴 것.
  void Function(MatchStats stats, {required bool opponentLeft})? onMatchEnd;

  /// uid → 상대.
  final remotes = <String, RemotePlayer>{};
  var players = <String, RoomPlayer>{};
  var hp = <String, NetHp>{};
  int scoreA = 0;
  int scoreB = 0;
  int _endsAt = 0;

  /// 최근 킬 3개(오래된 것 먼저).
  final killLog = <NetKill>[];

  /// 맞으면 1, 서서히 0. 화면 가장자리 빨간 깜빡임.
  double hurtFlash = 0;

  /// 죽었을 때 부활까지 남은 초.
  double respawnLeft = 0;

  int _kills = 0;
  int _deaths = 0;
  int _shots = 0;
  int _hits = 0;
  int _crits = 0;

  final _subs = <StreamSubscription<Object?>>[];
  final _pendingShots = <NetShot>[];
  int _offset = 0;
  double _sinceSend = 0;
  bool _sawOpponent = false;
  bool _stateInFlight = false;
  int _shotsInFlight = 0;
  static const _maxShotsInFlight = 8;
  bool _endWritten = false;
  bool _finished = false;

  /// [leave] 뒤. 화면이 닫히기 전까지 상태를 다시 쓰지 않게.
  bool _closed = false;

  int get serverNow => _clock() + _offset;

  /// 상대를 그리는 시각. 늦게 재생해야 두 스냅샷 사이를 보간할 수 있다.
  int get renderTime => serverNow - interpolationDelayMs;

  NetHp? get myHp => hp[uid];
  bool get isDead => (myHp?.value ?? 1) <= 0;
  bool isProtected(NetHp? h) => h != null && h.protectedUntil > serverNow;

  /// 시작 전(endsAt 모름)엔 전체 시간.
  int get remainingMs =>
      _endsAt == 0 ? matchDurationMs : max(0, _endsAt - serverNow);

  String nameOf(String id) => players[id]?.name ?? '?';

  @override
  void onMount() {
    _subs.addAll([
      rooms.serverTimeOffset().listen((o) => _offset = o),
      rooms.states(code).listen(_onStates),
      rooms.shots(code).listen((s) {
        if (s.by != uid) _pendingShots.add(s);
      }),
      rooms.players(code).listen(_onPlayers),
      rooms.hp(code).listen(_onHp),
      rooms.score(code).listen((s) {
        scoreA = s[RoomMeta.teamA] ?? 0;
        scoreB = s[RoomMeta.teamB] ?? 0;
      }),
      rooms.kills(code).listen((k) {
        killLog.add(k);
        if (killLog.length > 3) killLog.removeAt(0);
      }),
      rooms.meta(code).listen(_onMeta),
    ]);
    // 첫 체력은 서버 시간 오프셋을 안 뒤에(보호 시간이 서버 시간 기준이라).
    unawaited(
      rooms.serverTimeOffset().first.then((o) {
        _offset = o;
        return _writeFullHp();
      }),
    );
  }

  void _onStates(Map<String, NetState> states) {
    for (final MapEntry(key: id, value: s) in states.entries) {
      if (id == uid) continue;
      remotes
          .putIfAbsent(id, () {
            final r = RemotePlayer(sync: this, uid: id);
            game.world.add(r);
            return r;
          })
          .push(s);
    }
  }

  void _onPlayers(List<RoomPlayer> list) {
    players = {for (final p in list) p.uid: p};
    final opponentHere = list.any((p) => p.uid != uid && p.connected);
    if (opponentHere) _sawOpponent = true;
    if (_sawOpponent && !opponentHere) {
      _finish(MatchResult.win, opponentLeft: true);
    }
  }

  void _onHp(Map<String, NetHp> next) {
    final before = myHp?.value;
    hp = next;
    final now = myHp?.value;
    if (before == null || now == null || now >= before) return;
    hurtFlash = 1;
    if (now <= 0) {
      _deaths++;
      respawnLeft = respawnDelay;
    }
  }

  void _onMeta(RoomMeta? m) {
    if (m == null) return;
    _endsAt = m.endsAt;
    if (m.status != RoomMeta.ended) return;
    final outcome = switch (m.winner) {
      RoomMeta.teamA => MatchOutcome.aWins,
      RoomMeta.teamB => MatchOutcome.bWins,
      _ => MatchOutcome.draw,
    };
    _finish(resultFor(outcome, teamA: team == RoomMeta.teamA));
  }

  void _finish(MatchResult result, {bool opponentLeft = false}) {
    if (_finished || _closed) return;
    _finished = true;
    onMatchEnd?.call(
      MatchStats(
        result: result,
        kills: _kills,
        deaths: _deaths,
        shots: _shots,
        hits: _hits,
        crits: _crits,
      ),
      opponentLeft: opponentLeft,
    );
  }

  @override
  void update(double dt) {
    if (_closed) return;
    _sendState(dt);
    _spawnDueShots();
    hurtFlash = max(0, hurtFlash - dt * 2);
    if (respawnLeft > 0) {
      respawnLeft -= dt;
      if (respawnLeft <= 0) {
        respawnLeft = 0;
        game.respawnPlayer();
        unawaited(_writeFullHp());
      }
    }
    game.player.blinking = isProtected(myHp);
    if (isHost) _checkEnd();
  }

  /// 방장만 판정해서 meta에 기록한다. 둘 다 meta를 보고 결과 화면으로 간다.
  void _checkEnd() {
    if (_endWritten || _finished || _endsAt == 0) return;
    bool connected(String t) =>
        players.values.any((p) => p.team == t && p.connected);
    final outcome = matchEndState(
      scoreA: scoreA,
      scoreB: scoreB,
      remainingMs: _endsAt - serverNow,
      aConnected: connected(RoomMeta.teamA),
      bConnected: connected(RoomMeta.teamB),
    );
    if (outcome == MatchOutcome.ongoing) return;
    _endWritten = true;
    unawaited(
      rooms.endMatch(code, switch (outcome) {
        MatchOutcome.aWins => RoomMeta.teamA,
        MatchOutcome.bWins => RoomMeta.teamB,
        _ => RoomMeta.draw,
      }),
    );
  }

  Future<void> _writeFullHp() => rooms.setHp(
    code,
    uid,
    NetHp(
      value: basicSoldier.hp.toDouble(),
      protectedUntil: serverNow + spawnProtectionMs,
    ),
  );

  /// 이전 기록이 아직 안 끝났으면 건너뛴다. 서버가 느릴 때 요청이 쌓여
  /// 네이티브 스레드가 바닥나 앱이 죽는 걸 막는다(실제로 겪음).
  void _sendState(double dt) {
    _sinceSend += dt;
    if (_sinceSend < 1 / stateSendHz || _stateInFlight) return;
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

  /// 상대 몸과 같은 시각(renderTime)에 총알이 나가게 맞춘다. 연출만(나에게 데미지 없음).
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
    _shots++;
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

  /// 내 총알이 [victim]에 맞음(미스 아님). 내 화면 기준 판정이라 그대로 적용한다.
  void hit(String victim, HitResult h, WeaponStats weapon) {
    _hits++;
    if (h.crit) _crits++;
    unawaited(_damage(victim, h, weapon));
  }

  Future<void> _damage(String victim, HitResult h, WeaponStats weapon) async {
    final r = await rooms.damage(
      code,
      victim,
      (cur) => applyDamage(
        value: cur.value,
        protectedUntil: cur.protectedUntil,
        damage: h.damage,
        serverNow: serverNow,
      ),
    );
    if (r == null || !isKill(r.before, r.after)) return;
    _kills++;
    await rooms.recordKill(
      code,
      NetKill(killer: uid, victim: victim, weapon: weapon.id, crit: h.crit),
    );
    await rooms.addScore(code, team);
  }

  Future<void> leave() async {
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
