import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';

import '../../rules/balance.dart';
import '../../rules/combat.dart';
import '../../rules/cover.dart';
import '../../rules/movement.dart';
import '../soldier_game.dart';
import 'floating_text.dart';
import 'kill_feedback.dart';

/// 총알이 맞힐 수 있는 대상(훈련 표적, 상대). [key]는 같은 대상인지 가리는 용도.
typedef HitTarget = ({
  Object key,
  CoverBody body,
  Stance stance,
  bool protected,
  double evasion,
  void Function(HitResult hit, WeaponStats weapon) onHit,
});

/// [bulletSpeed]로 날아가다 사거리만큼 가면 사라진다.
/// 높은 벽: 불꽃 내고 사라짐 / 낮은 상자 뒤에 숨은 대상을 노린 총알: 상자에서 멈춤 /
/// 대상: resolveHit, 미스면 통과.
// ponytail: 프레임 이동 구간(선분)으로 판정하고 같은 구간 안 벽·표적의 앞뒤 순서는 안 따짐.
// 60fps면 12.5px라 문제없음. 큰 dt를 쓰는 곳이 생기면 교차 지점 거리로 정렬.
class Bullet extends PositionComponent with HasGameReference<SoldierGame> {
  Bullet({
    required super.position,
    required double angle,
    required this.weapon,
    required this.shooter,
    this.hitsTargets = true,
    this.targets,
    this.gradeMultiplier = 1.0,
    this.character = basicSoldier,
  }) : _dir = Vector2(cos(angle), sin(angle)),
       super(angle: angle);

  final WeaponStats weapon;

  /// 쏜 무기의 등급·강화 배율(decisions 7장). 봇·상대 총알은 E+0.
  final double gradeMultiplier;

  /// 쏜 사람 캐릭터(명중·크리). 봇·상대 화면 연출용 총알은 기본 병사 +0.
  final CharacterStats character;

  /// 쏜 순간 쏜 사람 상태(상자 위였는지 등).
  final CoverBody shooter;

  /// false = 상대 화면에 그리는 연출용(맞아도 아무 일 없음, 상자·벽에서만 멈춤).
  final bool hitsTargets;

  /// 맞힐 대상. 없으면 [SoldierGame.hitTargets](내가 쏜 총알). 봇 총알은 나를 넘긴다.
  final List<HitTarget> Function()? targets;
  final Vector2 _dir;
  double _traveled = 0;
  final _missed = <Object>{};

  /// 팀 색 예광탄(decisions 5장): 흰 중심 + 둘레 색. 내 총알 하늘색, 상대·봇 총알 빨강.
  // 회청색 바닥에서도 보이게 진한 파랑.
  static final _mineGlow = Paint()
    ..color = const Color(0xE61E7FE0)
    ..strokeWidth = 7
    ..strokeCap = StrokeCap.round;
  static final _enemyGlow = Paint()
    ..color = const Color(0xE6E53935)
    ..strokeWidth = 7
    ..strokeCap = StrokeCap.round;
  static final _core = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round;

  /// 내가 쏜 총알: 맞힐 수 있고 대상 목록을 따로 받지 않음(봇 총알은 나를 넘기고,
  /// 상대 화면 연출용 총알은 못 맞힌다).
  bool get mine => hitsTargets && targets == null;

  @override
  void update(double dt) {
    final step = min(bulletSpeed * dt, weapon.range - _traveled);
    final a = (x: position.x, y: position.y);
    final next = position + _dir * step;
    final b = (x: next.x, y: next.y);
    final map = game.map;

    if (lineBlockedByHighWall(a, b, map.highWalls)) {
      return _stop(const Color(0xFF98A089));
    }
    // 상자 뒤에 숨은 쪽을 노린 총알은 상자에서 멈춘다. 연출용 총알이 노리는 건 나.
    final targets = !hitsTargets
        ? const <HitTarget>[]
        : this.targets?.call() ?? game.hitTargets;
    final covered = hitsTargets
        ? [for (final t in targets) t.body]
        : [game.player.coverBody];
    for (final crate in map.lowCrates) {
      if (!segmentHitsBox(a, b, crate)) continue;
      final blocked =
          shooterBehindCover(shooter, crate) ||
          covered.any(
            (t) => bulletBlockedByLowCover(
              target: t,
              shooter: shooter,
              lowCrates: [crate],
            ),
          );
      if (blocked) return _stop(const Color(0xFFB08850));
    }
    for (final t in targets) {
      if (_missed.contains(t.key)) continue;
      if (distanceToSegment(t.body.pos, a, b) > hitRadius(t.stance)) continue;
      final at = Vector2(t.body.pos.x, t.body.pos.y);
      // 부활 보호 중: 총알만 멈추고 아무 일 없음.
      if (t.protected) return _stop(const Color(0xFFE3E6D8));
      final hit = _roll(t);
      if (hit.miss) {
        _missed.add(t.key);
        game.world.add(FloatingText.miss(at: at));
        continue;
      }
      t.onHit(hit, weapon);
      game.world.add(FloatingText.damage(hit.damage, at: at, crit: hit.crit));
      if (this.targets == null) {
        // 내 총알
        game.world.add(HitMarker(position: at));
        game.playHitSound();
      }
      return _stop(const Color(0xFFE0563F));
    }

    position.setFrom(next);
    _traveled += step;
    if (_traveled >= weapon.range) removeFromParent();
  }

  /// 내 명중과 맞는 쪽 회피(점프 중이면 +10%p)로 정한 미스 확률(decisions 5장).
  double missChanceAgainst(HitTarget t) => missChance(
    accuracy: character.accuracy,
    evasion: t.evasion,
    airborne: t.body.airborne,
  );

  HitResult _roll(HitTarget t) => resolveHit(
    baseDamage: weapon.pelletDamage,
    critMultiplier: weapon.critMultiplier,
    gradeMultiplier: gradeMultiplier,
    missChance: missChanceAgainst(t),
    critChance: critChance(
      weaponCrit: weapon.critChance,
      characterCrit: character.crit,
    ),
    missRoll: game.random.nextDouble(),
    critRoll: game.random.nextDouble(),
  );

  void _stop(Color color) {
    game.world.add(
      CircleComponent(
        radius: 4,
        position: position.clone(),
        anchor: Anchor.center,
        paint: Paint()..color = color,
        children: [RemoveEffect(delay: 0.15)],
      ),
    );
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    canvas
      ..drawLine(
        Offset.zero,
        const Offset(-16, 0),
        mine ? _mineGlow : _enemyGlow,
      )
      ..drawLine(Offset.zero, const Offset(-12, 0), _core);
  }
}
