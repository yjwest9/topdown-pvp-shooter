/// 밸런스 수치는 전부 여기에만 둔다. 출처: docs/decisions.md.
/// 확률·능력치는 0~1 비율(8% = 0.08).
library;

import 'dart:math' show pi;

// ---------------------------------------------------------- 조작 (2장)

/// 떠다니는 조이스틱 반경(px). 이만큼 밀면 입력 1.0.
const joystickRadius = 50.0;

/// 오른쪽 드래그 가로 1px당 회전(rad), 감도 기본값일 때.
/// 2026-10-12: 전체를 0.65배로 내림(0.0075 → 0.004875). 새 감도 10 ≈ 예전 6.5.
const turnPerPixel = 0.004875;

/// 감도는 소수 한 자리까지(5.7, 3.7 …).
const sensitivityStep = 0.1;
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

/// 강화 비용(골드)과 성공률. [i]는 지금 단계(+i → +i+1). 실패해도 무기는 그대로, 골드만 잃는다.
const upgradeCosts = <int>[2000, 4000, 6000, 8000, 10000];
const upgradeChances = <double>[0.9, 0.8, 0.7, 0.6, 0.5];

// ---------------------------------------------------------------- 무기 (6장)

enum WeaponFamily { rifle, sniper, shotgun, pistol }

/// 발사 방식. 무기마다가 아니라 주무기·보조무기 칸마다 정한다(설정, decisions 2장).
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
    required this.name,
    required this.pros,
    required this.cons,
    required this.family,
    required this.damage,
    required this.fireInterval,
    required this.critChance,
    required this.critMultiplier,
    required this.range,
    required this.magazine,
    required this.reloadTime,
    required this.spread,
    this.pellets = 1,
    this.moveSpeed = 1.0,
    this.moveSpreadScale = 1.0,
  });

  final String id;

  /// 화면에 보이는 이름(decisions 6장). 상표권자 요청이 오면 여기만 바꾼다.
  final String name;

  /// 장점·단점 한 줄(decisions 6장 표).
  final String pros;
  final String cons;
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
  name: 'K2',
  pros: '무난',
  cons: '특출난 점 없음',
  family: WeaponFamily.rifle,
  damage: 13,
  fireInterval: 0.11,
  critChance: 0.10,
  critMultiplier: 2.0,
  range: 560,
  magazine: 30,
  reloadTime: 1.8,
  spread: 0.035,
);
const rifleRapid = WeaponStats(
  id: 'rifle_rapid',
  name: 'FAMAS',
  pros: '근거리 강함, 탄창 40',
  cons: '퍼짐 커서 원거리 약함',
  family: WeaponFamily.rifle,
  damage: 10,
  fireInterval: 0.07,
  critChance: 0.10,
  critMultiplier: 2.0,
  range: 450,
  magazine: 40,
  reloadTime: 2.2,
  spread: 0.05,
);
const riflePrecision = WeaponStats(
  id: 'rifle_precision',
  name: 'M14',
  pros: '원거리 정확',
  cons: '빗나가면 손해, 탄창 15',
  family: WeaponFamily.rifle,
  damage: 26,
  fireInterval: 0.28,
  critChance: 0.10,
  critMultiplier: 2.0,
  range: 700,
  magazine: 15,
  reloadTime: 2.0,
  spread: 0.015,
);
const rifleHeavy = WeaponStats(
  id: 'rifle_heavy',
  name: 'M249',
  pros: '가장 빠른 킬',
  cons: '이동 ×0.75, 재장전 4초, 앉아야 정확',
  family: WeaponFamily.rifle,
  damage: 15,
  fireInterval: 0.10,
  critChance: 0.10,
  critMultiplier: 2.0,
  range: 520,
  magazine: 80,
  reloadTime: 4.0,
  spread: 0.06,
  moveSpeed: 0.75,
);
const sniperBolt = WeaponStats(
  id: 'sniper_bolt',
  name: 'TRG-42',
  pros: '크리티컬이면 한 방',
  cons: '놓치면 끝, 이동 느림',
  family: WeaponFamily.sniper,
  damage: 90,
  fireInterval: 1.3,
  critChance: 0.25,
  critMultiplier: 2.0,
  range: 1100,
  magazine: 5,
  reloadTime: 2.5,
  spread: 0.005,
  moveSpeed: 0.85,
);
const sniperSemi = WeaponStats(
  id: 'sniper_semi',
  name: 'SVD',
  pros: '연속 사격',
  cons: '한 방 없음',
  family: WeaponFamily.sniper,
  damage: 40,
  fireInterval: 0.45,
  critChance: 0.15,
  critMultiplier: 2.0,
  range: 950,
  magazine: 10,
  reloadTime: 2.4,
  spread: 0.01,
  moveSpeed: 0.9,
);
const sniperLight = WeaponStats(
  id: 'sniper_light',
  name: 'VSS',
  pros: '이동 중에도 정확',
  cons: '사거리 짧음',
  family: WeaponFamily.sniper,
  damage: 60,
  fireInterval: 0.9,
  critChance: 0.15,
  critMultiplier: 2.0,
  range: 850,
  magazine: 6,
  reloadTime: 2.2,
  spread: 0.008,
  moveSpreadScale: 0.5,
);
const shotgunPump = WeaponStats(
  id: 'shotgun_pump',
  name: 'M870',
  pros: '근거리 안정',
  cons: '사거리 260',
  family: WeaponFamily.shotgun,
  damage: 88,
  fireInterval: 0.8,
  critChance: 0.10,
  critMultiplier: 1.5,
  range: 260,
  magazine: 6,
  reloadTime: 2.2,
  spread: 0.25,
  pellets: 8,
);
const shotgunAuto = WeaponStats(
  id: 'shotgun_auto',
  name: 'M1014',
  pros: '근거리 최속',
  cons: '퍼짐 큼, 사거리 200',
  family: WeaponFamily.shotgun,
  damage: 48,
  fireInterval: 0.28,
  critChance: 0.10,
  critMultiplier: 1.5,
  range: 200,
  magazine: 8,
  reloadTime: 2.6,
  spread: 0.35,
  pellets: 8,
);
const shotgunDouble = WeaponStats(
  id: 'shotgun_double',
  name: 'SAWED-OFF',
  pros: '근접 역전 한 방',
  cons: '탄창 2, 재장전 2.6초',
  family: WeaponFamily.shotgun,
  damage: 110,
  fireInterval: 0.25,
  critChance: 0.10,
  critMultiplier: 1.5,
  range: 180,
  magazine: 2,
  reloadTime: 2.6,
  spread: 0.30,
  pellets: 10,
);
const pistol = WeaponStats(
  id: 'pistol',
  name: 'M9',
  pros: '주무기 재장전 중 대안',
  cons: '약함',
  family: WeaponFamily.pistol,
  damage: 15,
  fireInterval: 0.3,
  critChance: 0.10,
  critMultiplier: 2.0,
  range: 450,
  magazine: 12,
  reloadTime: 1.2,
  spread: 0.03,
);

/// 기본 지급 무기(decisions 6장). 등급은 E.
const startingPrimary = rifleStandard;
const startingSecondary = pistol;

/// 기본 지급이 아닌 무기의 E등급 가격(골드, decisions 9장).
const weaponPrice = 20000;

/// id로 무기 찾기. 없는 id면 null(옛 데이터 등).
WeaponStats? weaponById(String id) {
  for (final w in weapons) {
    if (w.id == id) return w;
  }
  return null;
}

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

// ------------------------------------------------------ 멀티플레이 (13장)

/// 내 상태를 초당 이 횟수만큼 기록한다.
const stateSendHz = 15;

/// 상대 상태를 이만큼(ms) 늦게 재생하며 보간한다.
const interpolationDelayMs = 100;

// ------------------------------------------------- 빠른 매칭 (13장)

/// 대기석 t가 이보다(ms) 오래되면 버려진 자리로 보고 새로 앉는다.
/// database.rules.json의 `now - 15000`과 같아야 한다.
const quickMatchStaleMs = 15000;

/// 대기하는 쪽이 t를 갱신하는 간격.
const quickMatchHeartbeat = Duration(seconds: 5);

/// 이미 누가 잡은 자리면 이만큼 뒤에 다시 본다.
const quickMatchRetry = Duration(milliseconds: 500);

/// 이만큼 기다려도 상대가 없으면 "봇과 대전" 버튼을 보여 준다.
const quickMatchBotOffer = Duration(seconds: 30);

/// 상대를 찾은 뒤 시작까지 카운트다운(초).
const quickMatchCountdown = 3;

// ------------------------------------------------- 매치 (11장, 12장) [잠정]

/// 팀 데스매치 시간.
const matchDurationMs = 180000;

/// 먼저 이 킬 수에 닿으면 끝.
const killsToWin = 20;

/// 죽고 나서 부활까지(초). 부스터 선택도 이 시간 안에.
const respawnDelay = 5.0;

/// 부활 직후 무적(ms).
const spawnProtectionMs = 3000;

// ------------------------------------------------- 매치 보상·레벨 (9장) [잠정]

/// 매치 골드. 무승부는 패배와 같게.
const winGold = 5000;
const loseGold = 2500;
const killGold = 200;

/// 매치 경험치.
const winExp = 100;
const loseExp = 50;
const killExp = 10;

/// 봇전 보상 비율(훈련소는 0).
const botRewardRate = 0.5;

/// 다음 레벨까지 필요한 경험치 = [levelExpBase] + [levelExpStep] × (현재 레벨 − 1).
const levelExpBase = 100;
const levelExpStep = 50;

/// 닉네임 길이.
const nicknameMin = 2;
const nicknameMax = 12;

// ------------------------------------------------- 상점 (9장) [잠정]

/// 보상형 광고 한 번에 받는 골드.
const adRewardGold = 10000;

/// 광고 쿨타임(서버 시간). database.rules.json의 users/$uid/lastAdAt 규칙(3600000)과
/// 같아야 한다. 바꾸면 거기도 바꿀 것.
const adCooldown = Duration(hours: 1);

/// 환전: [exchangeGoldCost] 골드 → [exchangeDiamonds] 다이아.
const exchangeGoldCost = 100000;
const exchangeDiamonds = 100;

// ------------------------------------------------- 빠른 매칭 재탐색 (13장)

/// 누가 내 자리를 잡고 이만큼 안에 방에 안 들어오면 새 방으로 다시 찾는다.
const quickMatchTakenTimeout = Duration(seconds: 10);

// ------------------------------------------------- 이벤트 (1장, 9장)

/// 공휴일(특일정보 API)에 매치 보상 배율.
const holidayRewardMultiplier = 2;

// ------------------------------------------------------------- 봇 (12장) [잠정]

enum BotDifficulty { easy, normal, hard }

class BotLevel {
  const BotLevel({
    required this.reaction,
    required this.aimError,
    required this.hideHp,
    required this.jumpPerSecond,
    required this.weapon,
  });

  /// 상대를 보고 첫 발까지(초).
  final double reaction;

  /// 발사마다 조준에 더하는 오차 ±(rad). 무기 퍼짐과 별도.
  final double aimError;

  /// 체력이 이 값 이하로 처음 떨어지면 엄폐하러 간다.
  final double hideHp;

  /// 교전 중 초당 점프 확률.
  final double jumpPerSecond;

  /// 봇 주무기(라이플만: 봇 AI가 라이플 거리 기준). 2026-10-12 측정(서 있는 나를 10초,
  /// 250/400px): 봇은 옆걸음하며 쏴서 정확한 M14가 가장 세고, M249는 가까우면 세고
  /// 멀면 퍼짐 때문에 약하다. FAMAS는 봇에게 가장 약해서 안 쓴다.
  final WeaponStats weapon;
}

const botLevels = <BotDifficulty, BotLevel>{
  BotDifficulty.easy: BotLevel(
    reaction: 0.6,
    aimError: 0.25,
    hideHp: 30,
    jumpPerSecond: 0.1,
    weapon: rifleStandard,
  ),
  BotDifficulty.normal: BotLevel(
    reaction: 0.35,
    aimError: 0.05,
    hideHp: 40,
    jumpPerSecond: 0.25,
    weapon: rifleHeavy,
  ),
  BotDifficulty.hard: BotLevel(
    reaction: 0.2,
    aimError: 0.0,
    hideHp: 50,
    jumpPerSecond: 0.4,
    weapon: riflePrecision,
  ),
};

/// 봇 조준: 상대 속도를 이 시간(초) 동안의 평균으로 본다(5장).
const botPredictWindow = 0.35;

/// 엄폐 자리를 찾는 거리(px).
const botCoverSearch = 350.0;

/// 엄폐하면 최소 이 시간(초)은 앉아 있는다.
const botCoverHold = 2.0;
