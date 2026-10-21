import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/room.dart';
import '../../data/repositories/room_repository.dart';
import '../../rules/aim.dart';
import '../../rules/balance.dart';
import '../../rules/bot.dart';
import '../../rules/combat.dart';
import '../../rules/cover.dart';
import '../../rules/match.dart';
import '../../rules/movement.dart';
import '../../rules/spawn.dart';
import '../net/match_sync.dart';
import '../soldier_game.dart';
import 'bullet.dart';
import 'player.dart';

/// 봇전의 봇(decisions 12장). 화면에 안 그리는 [Player]로 움직이고, 상태를 메모리 DB에 써서
/// 상대처럼([RemotePlayer]) 보인다. 체력·킬·점수는 PvP와 같은 길로 간다.
/// 1대1은 B팀 봇 하나가 나만 노린다. 2대2는 봇 셋(아군 1, 적 2)이 각자 보이는 적 중 가장
/// 가까운 적(나 또는 다른 팀 봇)을 노린다.
class BotSoldier extends Component with HasGameReference<SoldierGame> {
  BotSoldier({
    required this.match,
    required this.level,
    this.uid = RoomRepository.botUid,
    this.team = RoomMeta.teamB,
    this.allyIndex = 0,
  });

  final MatchSync match;
  final BotLevel level;
  final String uid;
  final String team;

  /// 같은 팀 안 순서. 2대2 시작 스폰이 겹치지 않게.
  final int allyIndex;

  late final Player body;
  late final NavGrid grid;
  bool _ready = false;

  /// 적마다 위치 기록(예측 조준용, 최근 1초).
  final _seen = <String, List<({double t, Vec p})>>{};
  double _t = 0;
  double _seenFor = 0;
  double _sinceSend = 0;
  double _repathIn = 0;
  var _path = <Vec>[];
  double _strafeIn = 0;
  double _strafeDir = 1;

  /// 죽은 뒤 부활까지 남은 초. 살아 있으면 null.
  double? _respawnIn;

  /// 부활 체력을 썼고 아직 반영 전(비동기)이라 다시 세지 않게.
  bool _waitingHp = false;

  /// 이번 생에 체력이 낮아 숨은 적이 있음.
  bool _hidUsed = false;
  Vec? _coverAt;
  double _coverLeft = 0;

  /// 숨기 시작 뒤 흐른 시간(초). [botHideMaxMs]가 지나면 나온다.
  double _hideFor = 0;

  /// 발각·시간 초과로 숨기를 끝냈으면 이 재장전이 끝날 때까지 다시 숨지 않는다.
  bool _hideBan = false;

  RoomRepository get _rooms => match.rooms;
  NetHp? get _hp => match.hp[uid];
  bool get _dead => (_hp?.value ?? 1) <= 0;
  Vec get _pos => (x: body.position.x, y: body.position.y);

  /// B팀(북쪽)은 남쪽을, A팀(남쪽)은 북쪽을 보고 선다.
  double get _spawnAngle => team == RoomMeta.teamB ? pi / 2 : -pi / 2;
  bool get _is2v2 => match.teamSize == 2;
  String get _enemyTeam =>
      team == RoomMeta.teamA ? RoomMeta.teamB : RoomMeta.teamA;

  @override
  Future<void> onLoad() async {
    final map = game.map;
    grid = NavGrid(
      width: map.width,
      height: map.height,
      blocks: [...map.highWalls, ...map.lowCrates],
    );
    final s = _spawn(start: true);
    body = Player(
      position: Vector2(s.x, s.y),
      angle: _spawnAngle,
      highWalls: map.highWalls,
      lowCrates: map.lowCrates,
      primaryWeapon: level.weapon,
    );
    _ready = true;
    unawaited(_writeFullHp());
  }

  /// 내 팀 스폰 중 적과 가장 먼 곳. 1대1은 나(사람)만 기준(예전 그대로).
  /// 2대2(decisions 12장): 시작은 적 진영 기준으로 팀 안 순서대로 먼 스폰부터 한 곳씩,
  /// 부활은 살아 있는 적 위치 기준으로 아군이 선 스폰을 피한다.
  Vec _spawn({bool start = false}) {
    final spawns = game.map.spawnsOf(team);
    if (!_is2v2) {
      return farthestSpawn(spawns, [
        (x: game.player.position.x, y: game.player.position.y),
      ]);
    }
    if (start) {
      return startSpawn(
        spawns,
        game.map.spawnsOf(_enemyTeam),
        allyIndex: allyIndex,
      );
    }
    final enemies = <Vec>[];
    final allies = <Vec>[];
    void add(String t, Vec p) => (t == team ? allies : enemies).add(p);
    add(match.team, (x: game.player.position.x, y: game.player.position.y));
    for (final b in _otherBots) {
      add(b.team, b._pos);
    }
    return respawnSpawn(spawns, enemies, allies);
  }

  Iterable<BotSoldier> get _otherBots =>
      game.children.whereType<BotSoldier>().where((b) => b != this && b._ready);

  Future<void> _writeFullHp() => _rooms.setHp(
    match.code,
    uid,
    NetHp(
      value: basicSoldier.hp.toDouble(),
      protectedUntil: match.serverNow + spawnProtectionMs,
    ),
  );

  @override
  void update(double dt) {
    _t += dt;
    final dead = _dead;
    if (!dead) _waitingHp = false;
    if (dead) {
      if (!_waitingHp) _countRespawn(dt);
    } else {
      _think(dt);
      body.update(dt);
      _fire(dt);
    }
    _send(dt);
  }

  void _countRespawn(double dt) {
    final left = (_respawnIn ?? respawnDelay) - dt;
    if (left > 0) {
      _respawnIn = left;
      return;
    }
    _respawnIn = null;
    _waitingHp = true;
    final s = _spawn();
    body.respawnAt(Vector2(s.x, s.y), _spawnAngle);
    _hidUsed = false;
    _coverAt = null;
    _path = [];
    _seenFor = 0;
    unawaited(_writeFullHp());
  }

  void _think(double dt) {
    final w = body.weapon;
    // 살아 있는 적 중 보이는 가장 가까운 적. 아무도 안 보이면 가장 가까운 적 쪽으로 간다.
    // 적이 모두 죽어 있으면(1대1에서 내가 죽은 동안) 예전처럼 쓰러진 적 쪽으로 간다.
    final alive = <BotCandidate>[], down = <BotCandidate>[];
    void add(String id, String t, CoverBody b, bool isDown) {
      if (t != team) (isDown ? down : alive).add((id: id, team: t, body: b));
    }

    add(match.uid, match.team, game.player.coverBody, match.isDead);
    for (final b in _otherBots) {
      add(b.uid, b.team, b.body.coverBody, b._dead);
    }
    for (final c in alive) {
      (_seen[c.id] ??= [])
        ..add((t: _t, p: c.body.pos))
        ..removeWhere((h) => h.t < _t - 1);
    }
    BotPick? choose(List<BotCandidate> list) => pickTarget(
      body.coverBody,
      team,
      list,
      range: w.weapon.range,
      highWalls: game.map.highWalls,
      lowCrates: game.map.lowCrates,
    );
    final pick = choose(alive);
    final chosen = pick ?? choose(down);
    if (chosen == null) {
      // 적이 아무도 없다: 제자리.
      body
        ..forward = 0
        ..strafe = 0
        ..wantsRun = false
        ..firing = false;
      return;
    }
    final target = [...alive, ...down].firstWhere((c) => c.id == chosen.id);
    final visible = pick?.visible ?? false;
    _seenFor = visible ? _seenFor + dt : 0;
    _repathIn -= dt;
    body
      ..forward = 0
      ..strafe = 0
      ..wantsRun = false
      ..firing = false;

    // 보이는데 재장전 중이거나, 이번 생에 처음 체력이 낮아지면 엄폐하러 간다.
    if (!w.reloading) _hideBan = false;
    final lowHp = !_hidUsed && (_hp?.value ?? basicSoldier.hp) <= level.hideHp;
    if (_coverAt == null && visible && !_hideBan && (w.reloading || lowHp)) {
      _coverAt = coverSpot(
        _pos,
        target.body.pos,
        game.map.lowCrates,
        walkable: grid.walkable,
      );
      if (_coverAt != null) {
        _coverLeft = botCoverHold;
        _hideFor = 0;
        _repathIn = 0;
        if (lowHp) _hidUsed = true;
      }
    }
    if (_coverAt case final spot?) {
      // 자리에 앉았는데 적이 보이면(발각), 또는 너무 오래 숨었으면 나와서 싸운다.
      _hideFor += dt;
      final dx = spot.x - _pos.x, dy = spot.y - _pos.y;
      final seated = dx * dx + dy * dy <= 6 * 6 && body.body.crouching;
      if (_hideFor * 1000 >= botHideMaxMs || (seated && visible)) {
        _coverAt = null;
        _hideBan = true;
        _repathIn = 0;
      } else {
        return _hide(dt, spot);
      }
    }
    _standUp();
    if (visible) {
      return _fight(dt, target.body.pos, _seen[target.id] ?? const []);
    }
    if (w.ammo < w.weapon.magazine / 2) w.reload();
    _goTo(target.body.pos, run: true);
  }

  void _hide(double dt, Vec spot) {
    final dx = spot.x - _pos.x, dy = spot.y - _pos.y;
    if (dx * dx + dy * dy > 6 * 6) return _goTo(spot, run: true);
    if (!body.body.crouching) body.body.toggleCrouch();
    body.weapon.reload();
    _coverLeft -= dt;
    if (_coverLeft <= 0 && !body.weapon.reloading) {
      _coverAt = null;
      _repathIn = 0;
    }
  }

  void _standUp() {
    if (body.body.crouching) body.body.toggleCrouch();
  }

  /// 예측 조준으로 상대를 보고, 옆걸음을 바꿔 가며, 반응 시간이 지나면 쏜다.
  void _fight(double dt, Vec target, List<({double t, Vec p})> seen) {
    body.angle = leadAngle(
      _pos,
      target,
      averageVelocity(seen, window: botPredictWindow),
    );
    _strafeIn -= dt;
    if (_strafeIn <= 0) {
      _strafeIn = 0.6 + game.random.nextDouble();
      _strafeDir = -_strafeDir;
    }
    body.strafe = _strafeDir;
    if (game.random.nextDouble() < level.jumpPerSecond * dt) body.body.jump();
    body.firing = _seenFor >= level.reaction;
  }

  /// 격자 길을 따라 [dest]로. 길은 0.5초마다 다시 찾는다.
  void _goTo(Vec dest, {required bool run}) {
    if (_repathIn <= 0) {
      _path = grid.path(_pos, dest);
      _repathIn = 0.5;
    }
    while (_path.isNotEmpty && _dist(_path.first) < 12) {
      _path.removeAt(0);
    }
    final next = _path.isEmpty ? dest : _path.first;
    body
      ..angle = atan2(next.y - _pos.y, next.x - _pos.x)
      ..forward = 1
      ..wantsRun = run;
  }

  double _dist(Vec p) => sqrt(pow(p.x - _pos.x, 2) + pow(p.y - _pos.y, 2));

  void _fire(double dt) {
    final w = body.weapon..tick(dt);
    if (!body.firing || !canFire(body.stance) || !w.tryFire()) return;
    w.cooldown += level.fireGap;
    final error = (game.random.nextDouble() * 2 - 1) * level.aimError;
    final angles = shotAngles(
      w.weapon,
      body.stance,
      aim: body.angle + error,
      roll: game.random.nextDouble(),
    );
    final muzzle =
        body.position +
        Vector2(cos(body.angle), sin(body.angle)) * (playerRadius + 10);
    game.playEnemyShot(w.weapon, muzzle); // 펠릿이 여러 개여도 한 번
    game.world.addAll([
      for (final a in angles)
        Bullet(
          position: muzzle.clone(),
          angle: a,
          weapon: w.weapon,
          shooter: body.coverBody,
          targets: targets,
        ),
    ]);
  }

  /// 봇 총알이 맞힐 수 있는 건 살아 있는 적뿐(나, 적 팀 봇). 아군은 통과한다(테스트도 본다).
  @visibleForTesting
  List<HitTarget> targets() {
    final p = game.player;
    return [
      if (match.team != team && !match.isDead)
        (
          key: p,
          body: p.coverBody,
          stance: p.stance,
          protected: match.isProtected(match.myHp),
          evasion: game.character.evasion,
          onHit: (h, w) => unawaited(_damage(match.uid, h, w)),
        ),
      for (final b in _otherBots)
        if (b.team != team && !b._dead)
          (
            key: b,
            body: b.body.coverBody,
            stance: b.body.stance,
            protected: match.isProtected(b._hp),
            evasion: basicSoldier.evasion,
            onHit: (h, w) => unawaited(_damage(b.uid, h, w)),
          ),
    ];
  }

  /// [MatchSync.hit]과 같은 길: 체력 트랜잭션 → 킬이면 기록 + 우리 팀 점수.
  Future<void> _damage(String victim, HitResult h, WeaponStats weapon) async {
    final r = await _rooms.damage(
      match.code,
      victim,
      (cur) => applyDamage(
        value: cur.value,
        protectedUntil: cur.protectedUntil,
        damage: h.damage,
        serverNow: match.serverNow,
      ),
    );
    if (r == null || !isKill(r.before, r.after)) return;
    await _rooms.recordKill(
      match.code,
      NetKill(killer: uid, victim: victim, weapon: weapon.id, crit: h.crit),
    );
    await _rooms.addScore(match.code, team);
  }

  void _send(double dt) {
    _sinceSend += dt;
    if (_sinceSend < 1 / stateSendHz) return;
    _sinceSend %= 1 / stateSendHz;
    unawaited(
      _rooms.sendState(
        match.code,
        uid,
        NetState(
          x: body.position.x,
          y: body.position.y,
          a: body.angle,
          stance: body.stance.name,
          up: body.lift,
          weapon: body.weapon.weapon.id,
          reloading: body.weapon.reloading,
        ),
      ),
    );
  }
}
