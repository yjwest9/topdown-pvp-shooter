import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';

import '../../data/models/room.dart';
import '../../data/repositories/room_repository.dart';
import '../../rules/aim.dart';
import '../../rules/balance.dart';
import '../../rules/bot.dart';
import '../../rules/combat.dart';
import '../../rules/match.dart';
import '../../rules/movement.dart';
import '../../rules/spawn.dart';
import '../net/match_sync.dart';
import '../soldier_game.dart';
import 'bullet.dart';
import 'player.dart';

/// 봇전의 봇(decisions 12장). 화면에 안 그리는 [Player]로 움직이고, 상태를 메모리 DB에 써서
/// 상대처럼([RemotePlayer]) 보인다. 체력·킬·점수는 PvP와 같은 길로 간다. 봇 총알은 나만 맞힌다.
class BotSoldier extends Component with HasGameReference<SoldierGame> {
  BotSoldier({required this.match, required this.level});

  final MatchSync match;
  final BotLevel level;
  static const uid = RoomRepository.botUid;

  late final Player body;
  late final NavGrid grid;

  /// 내 위치 기록(예측 조준용, 최근 1초).
  final _seen = <({double t, Vec p})>[];
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

  RoomRepository get _rooms => match.rooms;
  NetHp? get _hp => match.hp[uid];
  bool get _dead => (_hp?.value ?? 1) <= 0;
  Vec get _pos => (x: body.position.x, y: body.position.y);

  @override
  Future<void> onLoad() async {
    final map = game.map;
    grid = NavGrid(
      width: map.width,
      height: map.height,
      blocks: [...map.highWalls, ...map.lowCrates],
    );
    final s = _spawn();
    body = Player(
      position: Vector2(s.x, s.y),
      angle: pi / 2,
      highWalls: map.highWalls,
      lowCrates: map.lowCrates,
      primaryWeapon: level.weapon,
    );
    unawaited(_writeFullHp());
  }

  /// B팀 스폰 중 나와 가장 먼 곳.
  Vec _spawn() => farthestSpawn(game.map.spawnsOf(RoomMeta.teamB), [
    (x: game.player.position.x, y: game.player.position.y),
  ]);

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
    body.respawnAt(Vector2(s.x, s.y), pi / 2);
    _hidUsed = false;
    _coverAt = null;
    _path = [];
    _seenFor = 0;
    unawaited(_writeFullHp());
  }

  void _think(double dt) {
    final target = game.player.coverBody;
    _seen
      ..add((t: _t, p: target.pos))
      ..removeWhere((h) => h.t < _t - 1);
    final w = body.weapon;
    final visible =
        !match.isDead &&
        canSee(
          body.coverBody,
          target,
          range: w.weapon.range,
          highWalls: game.map.highWalls,
          lowCrates: game.map.lowCrates,
        );
    _seenFor = visible ? _seenFor + dt : 0;
    _repathIn -= dt;
    body
      ..forward = 0
      ..strafe = 0
      ..wantsRun = false
      ..firing = false;

    // 보이는데 재장전 중이거나, 이번 생에 처음 체력이 낮아지면 엄폐하러 간다.
    final lowHp = !_hidUsed && (_hp?.value ?? basicSoldier.hp) <= level.hideHp;
    if (_coverAt == null && visible && (w.reloading || lowHp)) {
      _coverAt = coverSpot(
        _pos,
        target.pos,
        game.map.lowCrates,
        walkable: grid.walkable,
      );
      if (_coverAt != null) {
        _coverLeft = botCoverHold;
        _repathIn = 0;
        if (lowHp) _hidUsed = true;
      }
    }
    if (_coverAt case final spot?) return _hide(dt, spot);
    _standUp();
    if (visible) return _fight(dt, target.pos);
    if (w.ammo < w.weapon.magazine / 2) w.reload();
    _goTo(target.pos, run: true);
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
  void _fight(double dt, Vec target) {
    body.angle = leadAngle(
      _pos,
      target,
      averageVelocity(_seen, window: botPredictWindow),
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
    game.world.addAll([
      for (final a in angles)
        Bullet(
          position: muzzle.clone(),
          angle: a,
          weapon: w.weapon,
          shooter: body.coverBody,
          targets: _targets,
        ),
    ]);
  }

  /// 봇 총알이 맞힐 수 있는 건 살아 있는 나뿐.
  List<HitTarget> _targets() {
    final p = game.player;
    if (match.isDead) return const [];
    return [
      (
        key: p,
        body: p.coverBody,
        stance: p.stance,
        protected: match.isProtected(match.myHp),
        onHit: (h, w) => unawaited(_damage(h, w)),
      ),
    ];
  }

  /// [MatchSync.hit]과 같은 길: 체력 트랜잭션 → 킬이면 기록 + B팀 점수.
  Future<void> _damage(HitResult h, WeaponStats weapon) async {
    final r = await _rooms.damage(
      match.code,
      match.uid,
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
      NetKill(killer: uid, victim: match.uid, weapon: weapon.id, crit: h.crit),
    );
    await _rooms.addScore(match.code, RoomMeta.teamB);
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
        ),
      ),
    );
  }
}
