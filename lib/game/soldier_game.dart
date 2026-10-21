import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/models/room.dart';
import '../data/repositories/room_repository.dart';
import '../data/repositories/sound_repository.dart';
import '../rules/aim.dart';
import '../rules/balance.dart';
import '../rules/combat.dart';
import '../rules/map_select.dart';
import '../rules/movement.dart';
import '../rules/sound.dart';
import '../rules/spawn.dart';
import '../rules/weapon_state.dart';
import 'components/bot_soldier.dart';
import 'components/bullet.dart';
import 'components/fire_button.dart';
import 'components/game_map.dart';
import 'components/kill_feedback.dart';
import 'components/match_hud.dart';
import 'components/minimap.dart';
import 'components/player.dart';
import 'components/remote_player.dart';
import 'components/round_button.dart';
import 'components/target_dummy.dart';
import 'components/test_map.dart';
import 'components/touch_controls.dart';
import 'components/weapon_hud.dart';
import 'game_art.dart';
import 'net/match_sync.dart';

class SoldierGame extends FlameGame with RiverpodGameMixin, KeyboardEvents {
  SoldierGame({
    this.sensitivity = defaultSensitivity,
    Random? random,
    this.match,
    this.minimapRotates = true,
    this.onMinimapRotatesChanged,
    this.bot,
    this.mapInfo = duelMap,
    this.primary = startingPrimary,
    this.secondary = startingSecondary,
    this.primaryGrade = Grade.e,
    this.secondaryGrade = Grade.e,
    this.primaryLevel = 0,
    this.secondaryLevel = 0,
    this.primaryFireMode = FireMode.auto,
    this.secondaryFireMode = FireMode.auto,
    this.character = basicSoldier,
    this.sound,
    this.soundEnabled = true,
  }) : random = random ?? Random();

  /// 내 장착 캐릭터(강화 반영). 최대 체력·이동 속도·내 총알의 명중·크리, 맞을 때 회피.
  final CharacterStats character;

  /// 로드아웃(decisions 6장). 숫자키 1~0 변경은 훈련소에서만.
  final WeaponStats primary;
  final WeaponStats secondary;

  /// 로드아웃 무기의 강화 단계. 내 총알 데미지에 배율로 들어간다.
  final Grade primaryGrade;
  final Grade secondaryGrade;
  final int primaryLevel;
  final int secondaryLevel;

  /// null이면 오프라인 훈련소(표적 있음). 있으면 1대1(표적 없음).
  final MatchSync? match;

  /// 있으면 봇전([match]는 메모리 DB 방, 상대는 봇).
  final BotDifficulty? bot;

  /// 1대1 맵(decisions 11장). 훈련소는 안 씀.
  final MapInfo mapInfo;

  /// 시점 감도 1~10.
  double sensitivity;

  /// 미니맵이 내 방향으로 도는지(true) 내 진영이 늘 아래인 고정인지(false).
  bool minimapRotates;

  /// 미니맵 모드를 눌러서 바꿨을 때(저장은 화면이 한다).
  final void Function(bool rotates)? onMinimapRotatesChanged;

  /// 내가 A팀(방장)인지. 훈련소는 A.
  bool get isTeamA => (match?.team ?? RoomMeta.teamA) == RoomMeta.teamA;

  void toggleMinimapMode() {
    minimapRotates = !minimapRotates;
    onMinimapRotatesChanged?.call(minimapRotates);
  }

  /// 효과음(decisions 17장). null이면 소리 없음(기존 테스트·훈련 없이 만든 게임).
  final SoundRepository? sound;

  /// 설정의 효과음 스위치. 끄면 아무 소리도 안 난다(게임 안 설정에서도 바꾼다).
  bool soundEnabled;

  /// 내 소리를 낸다([file]은 `rules/sound.dart`가 정한 이름). 모든 효과음은 여기를 거쳐서
  /// 스위치 하나로 꺼진다.
  void playSfx(String file, {double volume = 1}) {
    if (!soundEnabled) return;
    sound?.play(file, volume: volume);
  }

  double _clock = 0;
  double _lastHitSound = double.negativeInfinity;

  /// 내 총알이 맞힘(띵): 작게, [hitSoundGap] 안에 또 맞으면 한 번만.
  void playHitSound() {
    if (_clock - _lastHitSound < hitSoundGap) return;
    _lastHitSound = _clock;
    playSfx(Sfx.hit.file, volume: hitSoundVolume);
  }

  /// 상대(봇 포함) 총소리: 상대([at], 월드 좌표)가 내 화면 안에 있을 때만, 내 총소리의
  /// [enemyShotVolume]배로.
  void playEnemyShot(WeaponStats weapon, Vector2 at) {
    final p = camera.localToGlobal(at);
    if (p.x < 0 || p.y < 0 || p.x > size.x || p.y > size.y) return;
    playSfx(fireSound(weapon), volume: enemyShotVolume);
  }

  /// 내가 처치했다(표적이 쓰러짐, 상대 체력을 0으로 만듦): 처치 표시.
  void confirmKill(String victim) {
    killBanner.show(victim);
    playSfx(Sfx.kill.file);
  }

  /// 탄 퍼짐·미스·크리 랜덤. 테스트는 Random(seed)를 넣는다.
  final Random random;

  /// 주무기·보조무기 칸의 발사 방식(설정).
  FireMode primaryFireMode;
  FireMode secondaryFireMode;

  /// 사격 버튼을 누르고 있음(터치).
  bool fireButtonHeld = false;

  /// 병사·맵 그림(onLoad에서 불러온다).
  late final GameArt art;

  late final GameMap map;
  late final Player player;
  late final KillBanner killBanner;
  late final TextComponent stanceLabel;
  late final List<TargetDummy> dummies;

  final _keys = <LogicalKeyboardKey>{};

  /// 안드로이드 에뮬레이터는 PC 키를 누르고 있으면 누름·뗌을 반복해서 보낸다(테스트용 우회).
  /// 그래서 안드로이드에선 뗌을 바로 믿지 않고, 이 시간(초) 안에 다시 안 눌릴 때 뗀다.
  /// 첫 누름 뒤엔 PC 키 반복 지연(보통 0.5초)보다 길게, 반복이 시작되면 짧게.
  final _releaseIn = <LogicalKeyboardKey, double>{};
  final _repeating = <LogicalKeyboardKey>{};
  static const _firstReleaseDelay = 0.6;
  static const _repeatReleaseDelay = 0.12;
  bool _touchRun = false;

  /// 1대1에만 있다. 눌러도 조이스틱·회전이 시작되지 않게 터치 층에 알린다.
  Minimap? minimap;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final audio = sound;
    if (audio != null) unawaited(audio.load());
    art = GameArt(images);
    final loading = art.load();
    if (loading != null) await loading;
    // PvP는 고른 맵(빠른 대전은 duel, Tiled, decisions 11장), 훈련소는 하드코딩 테스트 맵 + 표적.
    map = match == null
        ? TestMap()
        : GameMap.fromTmx(await assets.readFile(mapInfo.asset));
    final spawn = _pickSpawn(start: true);
    player = Player(
      position: Vector2(spawn.x, spawn.y),
      angle: _spawnAngle,
      highWalls: map.highWalls,
      lowCrates: map.lowCrates,
      primaryWeapon: primary,
      secondaryWeapon: secondary,
      primaryGrade: primaryGrade,
      secondaryGrade: secondaryGrade,
      primaryLevel: primaryLevel,
      secondaryLevel: secondaryLevel,
      moveSpeed: character.moveSpeed,
    );
    dummies = [
      if (match == null)
        for (final d in TestMap.dummySpots)
          TargetDummy(
            position: Vector2(d.pos.x, d.pos.y),
            crouching: d.crouching,
            onCrate: d.onCrate,
          ),
    ];
    await world.addAll([map, ...dummies, player]);
    if (match != null) {
      await add(match!);
      if (bot case final b?) {
        final level = botLevels[b]!;
        // 2대2(decisions 12장): 적 봇 둘(B) + 아군 봇 하나(A), 난이도는 모두 같다.
        await addAll([
          BotSoldier(match: match!, level: level),
          if (match!.teamSize == 2) ...[
            BotSoldier(
              match: match!,
              level: level,
              uid: RoomRepository.allyBotUid,
              team: RoomMeta.teamA,
              allyIndex: 1,
            ),
            BotSoldier(
              match: match!,
              level: level,
              uid: RoomRepository.enemyBot2Uid,
              allyIndex: 1,
            ),
          ],
        ]);
      }
      // 왼쪽 위. 그 오른쪽에 설정 버튼(Flutter, MatchView).
      minimap = Minimap(position: Vector2(8, 8));
      await camera.viewport.addAll([MatchHud(match!), minimap!]);
    }

    // 플레이어가 화면 가로 중앙, 세로 66% 지점.
    camera.viewfinder.anchor = const Anchor(0.5, 0.66);
    killBanner = KillBanner();
    stanceLabel = TextComponent(
      // 미니맵(1대1에만) 아래, 없으면 왼쪽 위.
      position: Vector2(12, minimap == null ? 52 : Minimap.side + 16),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFE8B33A),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          shadows: [Shadow(color: Color(0xCC000000), blurRadius: 3)],
        ),
      ),
    );
    // 오른쪽 아래. 맨 아래 오른쪽은 사격 버튼.
    final fireButton = FireButton(
      visible: () => _fireMode == FireMode.manual,
      onFire: (held) => fireButtonHeld = held,
    );
    final buttons = <PositionComponent>[
      HudButtonComponent(
        button: RoundButton(label: 'JUMP', active: () => player.body.airborne),
        margin: const EdgeInsets.only(right: 122, bottom: 92),
        onPressed: () => player.body.jump(),
      ),
      HudButtonComponent(
        button: RoundButton(
          label: 'DUCK',
          radius: 28,
          active: () => player.body.crouching,
        ),
        margin: const EdgeInsets.only(right: 42, bottom: 148),
        onPressed: () => player.body.toggleCrouch(),
      ),
      HudButtonComponent(
        button: RoundButton(
          label: 'RELOAD',
          radius: 24,
          active: () => player.weapon.reloading,
        ),
        margin: const EdgeInsets.only(right: 128, bottom: 176),
        onPressed: () => player.weapon.reload(),
      ),
      // 오른쪽 위 무기 슬롯. 근접무기 슬롯은 나중에 왼쪽에 추가.
      for (final (i, primary) in [(1, true), (0, false)])
        WeaponSlot(
          label: primary ? 'PRIMARY' : 'SECONDARY',
          index: i,
          weapon: () => primary ? player.primary : player.secondary,
          active: () => player.usingPrimary == primary,
          fireMode: () => primary ? primaryFireMode : secondaryFireMode,
          onTap: () => player.selectSlot(primary: primary),
        ),
    ];
    await camera.viewport.addAll([
      TouchControls(
        onMove: (f, s, run) {
          player
            ..forward = f
            ..strafe = s;
          _touchRun = run;
          _syncRun();
        },
        onTurn: turnBy,
        buttons: [...buttons, ?minimap],
        isRunning: () => player.body.running,
        fireButton: fireButton,
      ),
      ...buttons,
      fireButton,
      killBanner,
      stanceLabel,
    ]);
    _syncCamera();
  }

  /// 오른쪽 화면 가로 드래그 [dragDx] px만큼 회전.
  void turnBy(double dragDx) => player.angle = turn(
    player.angle,
    dragDx: dragDx,
    sensitivity: sensitivity,
  );

  /// A팀(방장, 남쪽)·훈련소는 북쪽을, B팀(북쪽)은 남쪽을 보고 시작.
  double get _spawnAngle => isTeamA ? -pi / 2 : pi / 2;

  /// 내 팀 스폰 중 상대와 가장 먼 곳. 상대 위치를 모르면(시작) 상대 진영 스폰 기준.
  Vec _pickSpawn({bool start = false}) {
    final m = match;
    if (m == null) return TestMap.spawn;
    final enemyTeam = m.team == RoomMeta.teamA
        ? RoomMeta.teamB
        : RoomMeta.teamA;
    final seen = [
      for (final r in m.remotes.values)
        if (r.state != null && !m.isAlly(r.uid))
          (x: r.position.x, y: r.position.y),
    ];
    final spawns = map.spawnsOf(m.team);
    final enemies = seen.isEmpty ? map.spawnsOf(enemyTeam) : seen;
    if (m.teamSize == 1) return farthestSpawn(spawns, enemies);
    // 2대2(decisions 12장): 시작은 같은 팀끼리 uid 순서로 먼 스폰부터 한 곳씩, 부활은 아군이 선 곳을 피한다.
    if (start) return startSpawn(spawns, enemies, allyIndex: m.allyIndex);
    return respawnSpawn(spawns, enemies, [
      for (final r in m.allies) (x: r.position.x, y: r.position.y),
    ]);
  }

  /// 내 진영 스폰으로 되돌린다(부활). 탄약도 가득.
  void respawnPlayer() {
    final s = _pickSpawn();
    player.respawnAt(Vector2(s.x, s.y), _spawnAngle);
  }

  @override
  void update(double dt) {
    _clock += dt;
    _expireKeyReleases(dt);
    // 죽어 있는 동안은 움직이거나 쏘지 못한다.
    if (match?.isDead ?? false) {
      player
        ..forward = 0
        ..strafe = 0
        ..wantsRun = false;
    }
    final keyTurn =
        (_keys.contains(LogicalKeyboardKey.arrowRight) ? 1 : 0) -
        (_keys.contains(LogicalKeyboardKey.arrowLeft) ? 1 : 0);
    player.angle +=
        keyTurn * debugKeyTurnSpeed * (sensitivity / defaultSensitivity) * dt;
    // 이동 전에 정해야 달리던 중이면 이번 프레임부터 걷는다.
    player.firing = !(match?.isDead ?? false) && _wantsToFire();
    super.update(dt);
    _updateFiring(dt);
    _watchReload();
    _syncCamera();
    stanceLabel.text = _stanceText();
  }

  /// 총알·자동 사격 대상: 살아 있는 표적 + 살아 있는 상대.
  List<HitTarget> get hitTargets => [
    for (final d in dummies)
      if (!d.dead)
        (
          key: d,
          body: d.coverBody,
          stance: d.stance,
          protected: false,
          evasion: TargetDummy.stats.evasion,
          onHit: (h, _) {
            d.takeDamage(h.damage);
            if (d.dead) confirmKill('표적');
          },
        ),
    // 아군은 맞히지 않는다(총알이 통과, decisions 12장).
    for (final r in match?.remotes.values ?? const <RemotePlayer>[])
      if (r.targetable && match!.canHitRemote(r.uid))
        (
          key: r,
          body: r.coverBody,
          stance: r.stance,
          protected: r.protected,
          evasion: match!.characterOf(r.uid).evasion,
          onHit: (h, w) => match!.hit(r.uid, h, w),
        ),
  ];

  FireMode get _fireMode =>
      player.usingPrimary ? primaryFireMode : secondaryFireMode;

  bool get _triggerHeld =>
      fireButtonHeld || _keys.contains(LogicalKeyboardKey.arrowUp);

  /// 수동: 버튼(또는 ↑)을 누르는 동안. 자동: 자동 사격 대상이 있거나 ↑.
  /// 탄이 없거나 재장전 중이면 false(달리기를 끊지 않게).
  bool _wantsToFire() {
    final w = player.weapon;
    if (w.ammo == 0 || w.reloading) return false;
    if (_triggerHeld) return true;
    if (_fireMode != FireMode.auto) return false;
    return autoFireTarget(
          shooter: player.coverBody,
          aim: player.angle,
          range: w.weapon.range,
          targets: [for (final t in hitTargets) t.body],
          highWalls: map.highWalls,
          lowCrates: map.lowCrates,
        ) !=
        null;
  }

  /// 연사 간격·탄약은 WeaponState가 막는다. 달리는 중엔 못 쏜다.
  void _updateFiring(double dt) {
    final w = player.weapon..tick(dt);
    if (!player.firing || !canFire(player.stance) || !w.tryFire()) return;
    playSfx(fireSound(w.weapon)); // 펠릿이 여러 개여도 한 번
    final angles = shotAngles(
      w.weapon,
      player.stance,
      aim: player.angle,
      roll: random.nextDouble(),
    );
    final muzzle =
        player.position +
        Vector2(cos(player.angle), sin(player.angle)) * (playerRadius + 10);
    world.addAll([
      for (final a in angles)
        Bullet(
          position: muzzle.clone(),
          angle: a,
          weapon: w.weapon,
          shooter: player.coverBody,
          gradeMultiplier: gradeMultiplier(w.grade, w.level),
          character: character,
        ),
    ]);
    for (final a in angles) {
      match?.sendShot(muzzle, a, w.weapon.id);
    }
  }

  WeaponState? _watchedWeapon;
  bool _wasReloading = false;

  /// 재장전이 시작되는 순간 한 번 소리를 낸다(버튼·R 키·탄이 떨어져 자동 재장전 모두).
  void _watchReload() {
    final w = player.weapon;
    if (!identical(w, _watchedWeapon)) {
      _watchedWeapon = w; // 무기를 바꾼 프레임엔 새 무기 상태만 기억한다
    } else if (w.reloading && !_wasReloading) {
      playSfx(reloadSound(w.weapon.family));
    }
    _wasReloading = w.reloading;
  }

  String _stanceText() {
    final b = player.body;
    if (b.airborne) return 'JUMP';
    if (b.onCrate) return b.crouching ? 'ON CRATE · CROUCH' : 'ON CRATE';
    if (b.running) return 'RUN';
    if (b.crouching) return 'CROUCH';
    return 'STAND';
  }

  /// 정면이 화면 위가 되도록 카메라를 돌린다.
  /// 화면 위쪽 = 월드 (sin θ, −cos θ)이므로 θ = 플레이어 각도 + π/2.
  void _syncCamera() {
    camera.viewfinder
      ..position = player.position
      ..angle = player.angle + pi / 2;
  }

  bool get _shiftHeld =>
      _keys.contains(LogicalKeyboardKey.shiftLeft) ||
      _keys.contains(LogicalKeyboardKey.shiftRight);

  void _syncRun() => player.wantsRun = _touchRun || _shiftHeld;

  static final _moveKeys = {
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyD,
  };

  static final _gameKeys = {
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.keyC,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.keyQ,
    LogicalKeyboardKey.keyR,
    ..._weaponKeys,
  };

  /// 1~9, 0 = 주무기 10종(weapons 앞 10개). 훈련소에서만(디버그).
  static final _weaponKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
    LogicalKeyboardKey.digit0,
  ];

  /// 웹 디버그 키: WASD 이동, ←→ 회전, Space 점프, C/Ctrl 앉기, Shift 달리기,
  /// ↑ 사격, 1~9·0 주무기 선택, Q 주·보조 교체, R 재장전.
  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final key = event.logicalKey;
    if (!_gameKeys.contains(key)) return KeyEventResult.ignored;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (event is KeyDownEvent && _releaseIn.remove(key) != null) {
        _repeating.add(key);
        return KeyEventResult.handled; // 반복 누름: 점프·앉기를 다시 하지 않는다
      }
      if (event is KeyUpEvent) {
        _releaseIn[key] = _repeating.contains(key)
            ? _repeatReleaseDelay
            : _firstReleaseDelay;
      }
    }
    _keys
      ..clear()
      ..addAll(keysPressed)
      ..addAll(_releaseIn.keys);

    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.space) player.body.jump();
      if (key == LogicalKeyboardKey.keyC ||
          key == LogicalKeyboardKey.controlLeft ||
          key == LogicalKeyboardKey.controlRight) {
        player.body.toggleCrouch();
      }
      if (key == LogicalKeyboardKey.keyQ) player.swapWeapon();
      if (key == LogicalKeyboardKey.keyR) player.weapon.reload();
      final slot = _weaponKeys.indexOf(key);
      if (slot >= 0 && match == null) player.selectPrimary(weapons[slot]);
    }

    // WASD가 아닌 키(Space, C 등)는 이동값을 건드리지 않는다. 터치 조이스틱을
    // 쥔 채 Space/C를 눌러도 계속 가야 한다.
    if (_moveKeys.contains(key)) _syncMoveKeys();
    _syncRun();
    return KeyEventResult.handled;
  }

  void _syncMoveKeys() {
    double axis(LogicalKeyboardKey plus, LogicalKeyboardKey minus) =>
        (_keys.contains(plus) ? 1.0 : 0.0) -
        (_keys.contains(minus) ? 1.0 : 0.0);
    player
      ..forward = axis(LogicalKeyboardKey.keyW, LogicalKeyboardKey.keyS)
      ..strafe = axis(LogicalKeyboardKey.keyD, LogicalKeyboardKey.keyA);
  }

  /// 미뤄 둔 뗌([_releaseIn])이 시간이 다 되면 진짜로 뗀다.
  void _expireKeyReleases(double dt) {
    if (_releaseIn.isEmpty) return;
    final done = [
      for (final e in _releaseIn.entries)
        if ((_releaseIn[e.key] = e.value - dt) <= 0) e.key,
    ];
    if (done.isEmpty) return;
    for (final k in done) {
      _releaseIn.remove(k);
      _repeating.remove(k);
      _keys.remove(k);
    }
    if (done.any(_moveKeys.contains)) _syncMoveKeys();
    _syncRun();
  }
}
