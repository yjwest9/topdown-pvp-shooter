/// 밸런스 수치는 전부 여기에만 둔다. 출처: docs/decisions.md.
/// 확률·능력치는 0~1 비율(8% = 0.08).
library;

import 'dart:math' show pi;

// ---------------------------------------------------------- 조작 (2장)

/// 떠다니는 조이스틱 반경(px). 이만큼 밀면 입력 1.0.
const joystickRadius = 50.0;

/// 오른쪽 드래그 가로 1px당 회전(rad), 감도 기본값일 때.
const turnPerPixel = 0.0075;
const minSensitivity = 1.0;
const maxSensitivity = 10.0;
const defaultSensitivity = 5.0;

/// 웹 디버그 키 ←→ 회전 속도(rad/s), 감도 기본값일 때. 디버그용 제안값.
const debugKeyTurnSpeed = 3.0;

/// 조이스틱을 이 반경(px)까지 끌면 달리기.
const runRingRadius = 80.0;

/// 달리기는 이동 입력이 이 이상일 때만.
const runMinInput = 0.3;

/// 달리기는 정면 ±이 각도(rad) 안으로 밀 때만. [잠정]
const runMaxAngle = pi / 4;

// ---------------------------------------------------------------- 자세 (3장)

/// 걷기 기준 이동 속도(px/s). 자세별 배율은 [stanceStats].
const walkSpeed = 220.0;
const playerRadius = 16.0;

/// 이 속도(px/s)를 넘으면 걷기로 판정.
const movingSpeedThreshold = 30.0;
const jumpDuration = 0.5;

/// 점프 시작부터 다음 점프까지(착지 포함).
const jumpCooldown = 0.75;

/// 착지 때 몸이 낮은 상자 가장자리에 걸치면 공중을 이만큼씩 연장(미끄러져 내려옴).
const edgeSlideExtension = 0.03;

/// 앉으면 피격 반경 배율.
const crouchHitRadiusScale = 0.7;

// ---------------------------------------------------------- 엄폐 (4장)

/// 낮은 상자에서 이 거리(px) 이내에 앉아야 숨는다.
const lowCoverRange = 50.0;

enum Stance { standing, walking, running, crouching, jumping }

class StanceStats {
  const StanceStats({
    required this.speed,
    required this.spread,
    required this.canFire,
  });

  /// 이동 속도 배율 (걷기 = 1.0).
  final double speed;

  /// 탄 퍼짐 배율 (서서 정지 = 1.0).
  final double spread;
  final bool canFire;
}

const stanceStats = <Stance, StanceStats>{
  Stance.standing: StanceStats(speed: 1.0, spread: 1.0, canFire: true),
  Stance.walking: StanceStats(speed: 1.0, spread: 2.5, canFire: true),
  // canFire가 false라 spread는 사용 안 됨(걷기 값으로 둠).
  Stance.running: StanceStats(speed: 1.5, spread: 2.5, canFire: false),
  Stance.crouching: StanceStats(speed: 0.45, spread: 0.4, canFire: true),
  Stance.jumping: StanceStats(speed: 1.2, spread: 4.0, canFire: true),
};

// ---------------------------------------------------------- 전투 판정 (5장)

const missChanceBase = 0.05;
const missChanceMin = 0.0;
const missChanceMax = 0.20;

/// 점프 중인 상대를 쏘면 미스 확률 +10%p. [잠정]
const jumpMissBonus = 0.10;

/// [잠정, 설정값]
const critChanceCap = 0.30;

// ------------------------------------------------------ 등급과 강화 (7장)

enum Grade { e, d }

/// 등급별 +0 데미지 배율.
const gradeBaseMultiplier = <Grade, double>{Grade.e: 1.00, Grade.d: 1.10};
const damagePerUpgradeLevel = 0.02;

/// 무기·캐릭터 공통 강화 상한.
const maxUpgradeLevel = 5;

// ---------------------------------------------------------------- 무기 (6장)

enum WeaponFamily { rifle, sniper, shotgun, pistol }

enum FireMode { auto, manual }

/// 총알 속도(px/s), 모든 무기 공통.
const bulletSpeed = 750.0;

/// 자동 사격: 조준선 ±이 각도(rad) 안의 대상만.
const autoFireAngle = 0.14;

/// 훈련용 표적이 죽은 뒤 부활까지(초).
const dummyRespawnTime = 2.0;

class WeaponStats {
  const WeaponStats({
    required this.id,
    required this.family,
    required this.damage,
    required this.fireInterval,
    required this.critChance,
    required this.critMultiplier,
    required this.range,
    required this.magazine,
    required this.reloadTime,
    required this.spread,
    required this.fireMode,
    this.pellets = 1,
    this.moveSpeed = 1.0,
    this.moveSpreadScale = 1.0,
  });

  final String id;
  final WeaponFamily family;

  /// 샷건은 전 펠릿 명중 시 최대 데미지.
  final double damage;

  /// 연사 간격(초).
  final double fireInterval;
  final double critChance;
  final double critMultiplier;

  /// 총알이 날아가는 거리(px).
  final double range;
  final int magazine;

  /// 재장전 시간(초).
  final double reloadTime;

  /// 기본 퍼짐(rad). 단발은 조준선 ±spread, 샷건은 부채꼴 전체 폭.
  final double spread;

  /// 기본 발사 방식.
  final FireMode fireMode;
  final int pellets;

  /// 플레이어 이동 속도 배율.
  final double moveSpeed;

  /// 이동 중(걷기·점프) 퍼짐에 곱하는 배율.
  final double moveSpreadScale;

  double get pelletDamage => damage / pellets;
}

// [잠정] 초기 수치.
const rifleStandard = WeaponStats(
  id: 'rifle_standard',
  family: WeaponFamily.rifle,
  damage: 13,
  fireInterval: 0.11,
  critChance: 0.10,
  critMultiplier: 2.0,
  range: 560,
  magazine: 30,
  reloadTime: 1.8,
  spread: 0.035,
  fireMode: FireMode.auto,
);
const rifleRapid = WeaponStats(
  id: 'rifle_rapid',
  family: WeaponFamily.rifle,
  damage: 10,
  fireInterval: 0.07,
  critChance: 0.10,
  critMultiplier: 2.0,
  range: 450,
  magazine: 40,
  reloadTime: 2.2,
  spread: 0.05,
  fireMode: FireMode.auto,
);
const riflePrecision = WeaponStats(
  id: 'rifle_precision',
  family: WeaponFamily.rifle,
  damage: 26,
  fireInterval: 0.28,
  critChance: 0.10,
  critMultiplier: 2.0,
  range: 700,
  magazine: 15,
  reloadTime: 2.0,
  spread: 0.015,
  fireMode: FireMode.auto,
);
const rifleHeavy = WeaponStats(
  id: 'rifle_heavy',
  family: WeaponFamily.rifle,
  damage: 15,
  fireInterval: 0.10,
  critChance: 0.10,
  critMultiplier: 2.0,
  range: 520,
  magazine: 80,
  reloadTime: 4.0,
  spread: 0.06,
  fireMode: FireMode.auto,
  moveSpeed: 0.75,
);
const sniperBolt = WeaponStats(
  id: 'sniper_bolt',
  family: WeaponFamily.sniper,
  damage: 90,
  fireInterval: 1.3,
  critChance: 0.25,
  critMultiplier: 2.0,
  range: 1100,
  magazine: 5,
  reloadTime: 2.5,
  spread: 0.005,
  fireMode: FireMode.manual,
  moveSpeed: 0.85,
);
const sniperSemi = WeaponStats(
  id: 'sniper_semi',
  family: WeaponFamily.sniper,
  damage: 40,
  fireInterval: 0.45,
  critChance: 0.15,
  critMultiplier: 2.0,
  range: 950,
  magazine: 10,
  reloadTime: 2.4,
  spread: 0.01,
  fireMode: FireMode.manual,
  moveSpeed: 0.9,
);
const sniperLight = WeaponStats(
  id: 'sniper_light',
  family: WeaponFamily.sniper,
  damage: 60,
  fireInterval: 0.9,
  critChance: 0.15,
  critMultiplier: 2.0,
  range: 850,
  magazine: 6,
  reloadTime: 2.2,
  spread: 0.008,
  fireMode: FireMode.manual,
  moveSpreadScale: 0.5,
);
const shotgunPump = WeaponStats(
  id: 'shotgun_pump',
  family: WeaponFamily.shotgun,
  damage: 88,
  fireInterval: 0.8,
  critChance: 0.10,
  critMultiplier: 1.5,
  range: 260,
  magazine: 6,
  reloadTime: 2.2,
  spread: 0.25,
  fireMode: FireMode.auto,
  pellets: 8,
);
const shotgunAuto = WeaponStats(
  id: 'shotgun_auto',
  family: WeaponFamily.shotgun,
  damage: 48,
  fireInterval: 0.28,
  critChance: 0.10,
  critMultiplier: 1.5,
  range: 200,
  magazine: 8,
  reloadTime: 2.6,
  spread: 0.35,
  fireMode: FireMode.auto,
  pellets: 8,
);
const shotgunDouble = WeaponStats(
  id: 'shotgun_double',
  family: WeaponFamily.shotgun,
  damage: 110,
  fireInterval: 0.25,
  critChance: 0.10,
  critMultiplier: 1.5,
  range: 180,
  magazine: 2,
  reloadTime: 2.6,
  spread: 0.30,
  fireMode: FireMode.auto,
  pellets: 10,
);
const pistol = WeaponStats(
  id: 'pistol',
  family: WeaponFamily.pistol,
  damage: 15,
  fireInterval: 0.3,
  critChance: 0.10,
  critMultiplier: 2.0,
  range: 450,
  magazine: 12,
  reloadTime: 1.2,
  spread: 0.03,
  fireMode: FireMode.auto,
);

const weapons = <WeaponStats>[
  rifleStandard,
  rifleRapid,
  riflePrecision,
  rifleHeavy,
  sniperBolt,
  sniperSemi,
  sniperLight,
  shotgunPump,
  shotgunAuto,
  shotgunDouble,
  pistol,
];

// ------------------------------------------------------------ 캐릭터 (8장)

class CharacterStats {
  const CharacterStats({
    required this.id,
    required this.hp,
    this.accuracy = 0,
    this.evasion = 0,
    this.crit = 0,
    this.moveSpeed = 1.0,
    this.hpPerLevel = 0,
    this.accuracyPerLevel = 0,
    this.evasionPerLevel = 0,
    this.critPerLevel = 0,
  });

  final String id;
  final int hp;
  final double accuracy;
  final double evasion;
  final double crit;
  final double moveSpeed;

  // 강화 1단계마다 오르는 양.
  final int hpPerLevel;
  final double accuracyPerLevel;
  final double evasionPerLevel;
  final double critPerLevel;
}

const basicSoldier = CharacterStats(id: 'basic', hp: 100, hpPerLevel: 2);
const marksman = CharacterStats(
  id: 'marksman',
  hp: 95,
  accuracy: 0.08,
  accuracyPerLevel: 0.01,
);
const scout = CharacterStats(
  id: 'scout',
  hp: 90,
  evasion: 0.08,
  moveSpeed: 1.05,
  evasionPerLevel: 0.01,
);
const assault = CharacterStats(
  id: 'assault',
  hp: 95,
  crit: 0.05,
  critPerLevel: 0.01,
);

const characters = <CharacterStats>[basicSoldier, marksman, scout, assault];
