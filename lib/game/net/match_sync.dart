import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';

import '../../data/models/match_stats.dart';
import '../../data/models/room.dart';
import '../../data/repositories/room_repository.dart';
import '../../rules/balance.dart';
import '../../rules/character.dart';
import '../../rules/combat.dart';
import '../../rules/match.dart';
import '../../rules/room_teams.dart';
import '../../rules/sound.dart';
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
    this.teamSize = 1,
    this.allyIndex = 0,
    int Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final RoomRepository rooms;
  final String code;
  final String uid;
  final bool isHost;

  /// 한 팀 인원(1 또는 2). 처음엔 대기실에서 받은 값, 방 meta를 읽으면 meta 값.
  int teamSize;

  /// 같은 팀 사람 중 내 순서(uid 순). 2대2 시작 스폰이 겹치지 않게(decisions 12장).
  final int allyIndex;
  final int Function() _clock;

  /// 내 팀. 대기실에서 정한 팀(A는 남쪽, B는 북쪽). 아직 못 읽었으면 방장 A, 참가자 B.
  String get team {
    final me = players[uid];
    return me != null && me.hasTeam
        ? me.team
        : (isHost ? RoomMeta.teamA : RoomMeta.teamB);
  }

  bool get isTeamA => team == RoomMeta.teamA;

  /// 매치가 끝나면 한 번 불린다. [opponentLeft]면 상대가 나가서 이긴 것.
  void Function(MatchStats stats, {required bool opponentLeft})? onMatchEnd;

  /// 매치가 시작돼(방 meta에 끝나는 시각이 생겨) [statsFor]의 matchId가 정해지면 한 번 불린다.
  void Function(String matchId)? onStart;

  /// uid → 상대.
  final remotes = <String, RemotePlayer>{};
  var players = <String, RoomPlayer>{};
  var hp = <String, NetHp>{};
  int scoreA = 0;
  int scoreB = 0;
  int _endsAt = 0;
  String? _hostUid;

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
  bool _sawMeConnected = false;
  int? _meLostSince;
  int? _opponentGoneSince;
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

  /// 같은 팀(나 제외). team이 없거나 A/B가 아닌 참가자는 아군이 아니라 적이다.
  bool isAlly(String id) =>
      id != uid && (players[id]?.hasTeam ?? false) && players[id]!.team == team;

  /// 나 말고, 아군이 아닌 참가자(적).
  bool _isEnemy(RoomPlayer p) => p.uid != uid && !isAlly(p.uid);

  /// 내 총알이 맞힐 수 있는 상대인가(아군은 통과, decisions 12장).
  bool canHitRemote(String id) => canHit(
    shooterTeam: team,
    targetTeam: (players[id]?.hasTeam ?? false) ? players[id]!.team : '',
  );

  /// 보이는 아군들(미니맵 파란 점).
  Iterable<RemotePlayer> get allies => [
    for (final r in remotes.values)
      if (isAlly(r.uid) && r.targetable) r,
  ];

  /// 매치 결과를 기록하는 사람: 방장이 연결돼 있으면 방장, 아니면 uid가 가장 작은 연결된 사람.
  /// 참가자 목록을 아직 못 받았으면 방장만(1대1과 같게).
  bool get isFinisher {
    if (players.isEmpty) return isHost;
    return finisherUid(
          hostUid: _hostUid ?? (isHost ? uid : ''),
          players: [
            for (final p in players.values)
              (uid: p.uid, connected: p.connected),
          ],
        ) ==
        uid;
  }

  /// 방 참가자의 캐릭터(강화 반영). 기록이 없으면(옛 앱·봇) 기본 병사 +0.
  CharacterStats characterOf(String id) =>
      characterStats(players[id]?.character, players[id]?.characterLevel ?? 0);

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
    if (list.any((p) => _isEnemy(p) && p.connected)) _sawOpponent = true;
    if (players[uid]?.connected ?? false) _sawMeConnected = true;
  }

  /// 상대 이탈·내 끊김·방장이 끝을 기록하지 못하는 경우의 마무리(demo-risks 2·3-1).
  /// 방장은 자기 `_checkEnd`가 끝을 기록한다. 연결 표시가 꺼진 것은 [stuckGraceMs] 넘게 그대로일
  /// 때만 믿는다(잠깐 꺼졌다 켜지거나 시작 직후 아직 안 써진 경우에 잘못 끝내지 않게).
  void _checkStuck() {
    if (_finished || _closed) return;
    // 상대 팀이 모두 나갔다(2대2에서 한 명만 나가면 계속): 연결 표시가 꺼졌거나 항목이 사라졌다.
    // 참가자는 방장이 연결된 걸 본 적이 없어도(시작했는데 꺼져 있음) 인정한다.
    final others = players.values.where(_isEnemy);
    final gone =
        others.every((p) => !p.connected) &&
        (_sawOpponent || (!isHost && _endsAt != 0 && others.isNotEmpty));
    _opponentGoneSince = gone ? (_opponentGoneSince ?? serverNow) : null;
    if (gone && serverNow - _opponentGoneSince! >= stuckGraceMs) {
      _finish(MatchResult.win, opponentLeft: true);
      return;
    }
    if (_endsAt == 0) return;
    // 내 연결 표시가 꺼졌다 = 서버가 나를 끊긴 사람으로 봤다(상대는 이미 이긴 것으로 끝냄).
    final meLost = _sawMeConnected && players[uid]?.connected == false;
    _meLostSince = meLost ? (_meLostSince ?? serverNow) : null;
    if (meLost && serverNow - _meLostSince! >= stuckGraceMs) {
      _finish(MatchResult.lose);
      return;
    }
    if (isFinisher) return;
    // 마무리 담당이 살아 있는데도 끝 기록이 안 옴: 시간이 끝나고 몇 초 뒤 내 화면의 점수로 끝낸다.
    if (serverNow - _endsAt > hostEndGraceMs) {
      _finish(
        resultFor(
          matchEndState(
            scoreA: scoreA,
            scoreB: scoreB,
            remainingMs: 0,
            aConnected: true,
            bConnected: true,
          ),
          teamA: false,
        ),
      );
    }
  }

  void _onHp(Map<String, NetHp> next) {
    final before = myHp?.value;
    hp = next;
    final now = myHp?.value;
    if (before == null || now == null || now >= before) return;
    hurtFlash = 1;
    game.playSfx(Sfx.hurt.file);
    if (now <= 0) {
      _deaths++;
      respawnLeft = respawnDelay;
    }
  }

  void _onMeta(RoomMeta? m) {
    if (m == null) return;
    final started = _endsAt == 0 && m.endsAt != 0;
    _endsAt = m.endsAt;
    _hostUid = m.hostUid;
    teamSize = m.teamSize;
    if (started) onStart?.call('$code-$_endsAt');
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
    switch (result) {
      case MatchResult.win:
        game.playSfx(Sfx.win.file);
      case MatchResult.lose:
        game.playSfx(Sfx.lose.file);
      case MatchResult.draw:
        break;
    }
    onMatchEnd?.call(statsFor(result), opponentLeft: opponentLeft);
  }

  /// 지금까지의 내 기록. 중간에 나갈 때도 쓴다(패배 기록).
  MatchStats statsFor(MatchResult result) => MatchStats(
    matchId: '$code-$_endsAt',
    result: result,
    kills: _kills,
    deaths: _deaths,
    shots: _shots,
    hits: _hits,
    crits: _crits,
    ownScore: teamSize == 2 ? (isTeamA ? scoreA : scoreB) : null,
    enemyScore: teamSize == 2 ? (isTeamA ? scoreB : scoreA) : null,
  );

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
    if (isFinisher) _checkEnd();
    _checkStuck();
  }

  /// 마무리 담당(방장, 방장이 나갔으면 남은 사람 중 uid가 가장 작은 사람)만 판정해서 meta에
  /// 기록한다. 모두 meta를 보고 결과 화면으로 간다.
  void _checkEnd() {
    if (_endWritten || _finished || _endsAt == 0) return;
    // 상대가 나간 것은 `_checkStuck`이 유예(stuckGraceMs)를 두고 처리한다. 여기서 바로 끝내면
    // 잠깐 끊겼다 돌아온 상대가 졌다고 나온다.
    final outcome = matchEndState(
      scoreA: scoreA,
      scoreB: scoreB,
      remainingMs: _endsAt - serverNow,
      aConnected: true,
      bConnected: true,
      toWin: killsToWinFor(teamSize),
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
      value: game.character.hp.toDouble(),
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
              reloading: p.weapon.reloading,
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
      final weapon = weapons.firstWhere((w) => w.id == s.weapon);
      _playShotSound(s, weapon);
      game.world.add(
        Bullet(
          position: Vector2(s.x, s.y),
          angle: s.a,
          weapon: weapon,
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

  /// 상대 총소리. 샷건 펠릿은 한 발씩 따로 오지만 한 번 쏜 소리 하나만 낸다
  /// (같은 사람의 펠릿이 [_volleyGapMs] 안에 연달아 오면 한 번으로 본다).
  void _playShotSound(NetShot s, WeaponStats weapon) {
    final last = _volleyAt[s.by];
    if (weapon.pellets > 1 && last != null && s.t - last <= _volleyGapMs) {
      return;
    }
    _volleyAt[s.by] = s.t;
    game.playEnemyShot(weapon, Vector2(s.x, s.y));
  }

  final _volleyAt = <String, int>{};
  static const _volleyGapMs = 100;

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
    if (!_closed) game.confirmKill(nameOf(victim));
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
