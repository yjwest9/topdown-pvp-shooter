/// 밸런스 수치는 전부 여기에만 둔다. 출처: docs/decisions.md.
/// 확률·능력치는 0~1 비율(8% = 0.08).
library;

// ---------------------------------------------------------------- 자세 (3장)

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

class WeaponStats {
  const WeaponStats({
    required this.id,
    required this.family,
    required this.damage,
    required this.fireInterval,
    required this.critChance,
    required this.critMultiplier,
  });

  final String id;
  final WeaponFamily family;

  /// 샷건은 전 펠릿 명중 시 최대 데미지.
  final double damage;

  /// 연사 간격(초).
  final double fireInterval;
  final double critChance;
  final double critMultiplier;
}

// [잠정] 초기 수치.
const rifleStandard = WeaponStats(
  id: 'rifle_standard',
  family: WeaponFamily.rifle,
  damage: 13,
  fireInterval: 0.11,
  critChance: 0.10,
  critMultiplier: 2.0,
);
const rifleRapid = WeaponStats(
  id: 'rifle_rapid',
  family: WeaponFamily.rifle,
  damage: 9,
  fireInterval: 0.07,
  critChance: 0.10,
  critMultiplier: 2.0,
);
const riflePrecision = WeaponStats(
  id: 'rifle_precision',
  family: WeaponFamily.rifle,
  damage: 26,
  fireInterval: 0.28,
  critChance: 0.10,
  critMultiplier: 2.0,
);
const rifleHeavy = WeaponStats(
  id: 'rifle_heavy',
  family: WeaponFamily.rifle,
  damage: 15,
  fireInterval: 0.10,
  critChance: 0.10,
  critMultiplier: 2.0,
);
const sniperBolt = WeaponStats(
  id: 'sniper_bolt',
  family: WeaponFamily.sniper,
  damage: 90,
  fireInterval: 1.3,
  critChance: 0.25,
  critMultiplier: 2.0,
);
const sniperSemi = WeaponStats(
  id: 'sniper_semi',
  family: WeaponFamily.sniper,
  damage: 40,
  fireInterval: 0.45,
  critChance: 0.15,
  critMultiplier: 2.0,
);
const sniperLight = WeaponStats(
  id: 'sniper_light',
  family: WeaponFamily.sniper,
  damage: 60,
  fireInterval: 0.9,
  critChance: 0.15,
  critMultiplier: 2.0,
);
const shotgunPump = WeaponStats(
  id: 'shotgun_pump',
  family: WeaponFamily.shotgun,
  damage: 88,
  fireInterval: 0.8,
  critChance: 0.10,
  critMultiplier: 1.5,
);
const shotgunAuto = WeaponStats(
  id: 'shotgun_auto',
  family: WeaponFamily.shotgun,
  damage: 48,
  fireInterval: 0.28,
  critChance: 0.10,
  critMultiplier: 1.5,
);
const shotgunDouble = WeaponStats(
  id: 'shotgun_double',
  family: WeaponFamily.shotgun,
  damage: 110,
  fireInterval: 0.25,
  critChance: 0.10,
  critMultiplier: 1.5,
);
const pistol = WeaponStats(
  id: 'pistol',
  family: WeaponFamily.pistol,
  damage: 15,
  fireInterval: 0.3,
  critChance: 0.10,
  critMultiplier: 2.0,
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
