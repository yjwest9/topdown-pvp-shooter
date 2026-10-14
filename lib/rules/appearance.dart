import 'balance.dart';

/// 병사 그림 포즈(Kenney Top-down Shooter, decisions 3장·8장).
enum Pose { stand, machine, silencer, gun, reload }

/// 무기 종류에 따른 포즈. 재장전 중이면 reload.
/// 라이플(M249 포함)·샷건 = machine, 저격총 = silencer, 권총 = gun.
Pose poseFor(WeaponFamily family, {bool reloading = false}) {
  if (reloading) return Pose.reload;
  return switch (family) {
    WeaponFamily.rifle || WeaponFamily.shotgun => Pose.machine,
    WeaponFamily.sniper => Pose.silencer,
    WeaponFamily.pistol => Pose.gun,
  };
}

/// 캐릭터 id → Kenney 캐릭터 그림 이름 앞부분(8장: Soldier 1 / Hitman 1 / Survivor 1 / Man Brown).
const _characterArt = {
  'basic': 'soldier1',
  'marksman': 'hitman1',
  'scout': 'survivor1',
  'assault': 'manBrown',
};

/// `assets/images/` 안의 파일 이름. 모르는 id는 기본 병사.
String characterSprite(String? characterId, Pose pose) =>
    '${_characterArt[characterId] ?? _characterArt['basic']}_${pose.name}.png';

/// 맵 타일(64px 그림을 70px 칸에 늘려 쓴다, decisions 4장).
const floorTiles = ['tile_07.png', 'tile_08.png'];
const wallTile = 'tile_171.png';
const crateTile = 'tile_129.png';

/// 게임이 쓰는 그림 전부(처음에 한 번 불러온다).
final artFiles = <String>[
  for (final c in characters)
    for (final pose in Pose.values) characterSprite(c.id, pose),
  ...floorTiles,
  wallTile,
  crateTile,
];

// ------------------------------------------------- 무기 그림(옆모습, decisions 17장)

enum Stock { none, solid, skeleton, folding, thumbhole }

enum Magazine { none, curved, box, ammoBox, tube }

enum Optic { none, redDot, scope, longScope, carryHandle }

/// 몸통·손잡이 색.
enum Finish { black, wood, olive, tan }

/// 무기 한 종류의 옆모습 모양 값. 이 값으로 코드가 그린다(로고·각인 없음).
class WeaponLook {
  const WeaponLook({
    required this.length,
    this.stock = Stock.solid,
    this.magazine = Magazine.box,
    this.optic = Optic.none,
    this.finish = Finish.black,
    this.bipod = false,
    this.barrels = 1,
    this.bullpup = false,
    this.suppressor = false,
    this.pump = false,
    this.pistol = false,
  });

  /// 총 길이(그림 단위). 권총 34 ~ 저격총 124. 상세·목록에서 상대 크기로도 쓴다.
  final double length;
  final Stock stock;
  final Magazine magazine;
  final Optic optic;
  final Finish finish;
  final bool bipod;
  final int barrels;

  /// 탄창이 손잡이 뒤에 있는 형태(개머리판이 몸통).
  final bool bullpup;

  /// 총열 전체가 굵은 소음기.
  final bool suppressor;

  /// 총열 아래 펌프 손잡이.
  final bool pump;
  final bool pistol;

  @override
  bool operator ==(Object other) =>
      other is WeaponLook &&
      other.length == length &&
      other.stock == stock &&
      other.magazine == magazine &&
      other.optic == optic &&
      other.finish == finish &&
      other.bipod == bipod &&
      other.barrels == barrels &&
      other.bullpup == bullpup &&
      other.suppressor == suppressor &&
      other.pump == pump &&
      other.pistol == pistol;

  @override
  int get hashCode => Object.hash(
    length,
    stock,
    magazine,
    optic,
    finish,
    bipod,
    barrels,
    bullpup,
    suppressor,
    pump,
    pistol,
  );
}

/// 무기 id → 모양(실제 총의 특징만 따서).
const weaponLooks = <String, WeaponLook>{
  // K2: 접이식 개머리판, 휜 탄창
  'rifle_standard': WeaponLook(
    length: 92,
    stock: Stock.folding,
    magazine: Magazine.curved,
  ),
  // FAMAS: 불펍 + 위쪽 긴 손잡이
  'rifle_rapid': WeaponLook(
    length: 78,
    stock: Stock.none,
    magazine: Magazine.box,
    optic: Optic.carryHandle,
    bullpup: true,
  ),
  // M14: 나무 개머리판·총열 덮개, 곧은 탄창
  'rifle_precision': WeaponLook(
    length: 112,
    magazine: Magazine.box,
    finish: Finish.wood,
  ),
  // M249: 탄통, 양각대, 손잡이
  'rifle_heavy': WeaponLook(
    length: 104,
    stock: Stock.skeleton,
    magazine: Magazine.ammoBox,
    optic: Optic.carryHandle,
    bipod: true,
  ),
  // TRG-42: 올리브 개머리판, 긴 조준경, 양각대
  'sniper_bolt': WeaponLook(
    length: 124,
    magazine: Magazine.box,
    optic: Optic.longScope,
    finish: Finish.olive,
    bipod: true,
  ),
  // SVD: 나무, 엄지 구멍 개머리판, 조준경
  'sniper_semi': WeaponLook(
    length: 122,
    stock: Stock.thumbhole,
    magazine: Magazine.curved,
    optic: Optic.scope,
    finish: Finish.wood,
  ),
  // VSS: 굵은 일체형 소음기, 뼈대 개머리판
  'sniper_light': WeaponLook(
    length: 98,
    stock: Stock.skeleton,
    magazine: Magazine.box,
    optic: Optic.scope,
    finish: Finish.wood,
    suppressor: true,
  ),
  // M870: 펌프, 관형 탄창
  'shotgun_pump': WeaponLook(
    length: 100,
    magazine: Magazine.tube,
    pump: true,
    finish: Finish.wood,
  ),
  // M1014: 반자동, 관형 탄창, 접이식 개머리판, 도트
  'shotgun_auto': WeaponLook(
    length: 98,
    stock: Stock.folding,
    magazine: Magazine.tube,
    optic: Optic.redDot,
    finish: Finish.tan,
  ),
  // 수평 쌍대(짧게 자른) 산탄총
  'shotgun_double': WeaponLook(
    length: 64,
    magazine: Magazine.none,
    finish: Finish.wood,
    barrels: 2,
  ),
  // M9 권총
  'pistol': WeaponLook(
    length: 34,
    stock: Stock.none,
    magazine: Magazine.none,
    pistol: true,
  ),
};

/// 모르는 id는 K2 모양.
WeaponLook weaponLook(String id) =>
    weaponLooks[id] ?? weaponLooks['rifle_standard']!;

// ------------------------------------------------- 정면 캐릭터(홈·캐릭터 화면, decisions 8장)

/// 정면에서 본 서 있는 모습의 옷·머리 색(ARGB). 게임 안 Kenney 그림 색과 맞춘다.
class CharacterLook {
  const CharacterLook({
    required this.skin,
    required this.hair,
    required this.top,
    required this.pants,
    required this.shoes,
    this.accent,
    this.helmet = false,
    this.backpack = false,
    this.tie = false,
    this.sunglasses = false,
    this.messyHair = false,
    this.headset = false,
  });

  final int skin;
  final int hair;
  final int top;
  final int pants;
  final int shoes;

  /// 헬멧·가방끈·넥타이 등 포인트 색. 없으면 옷 색보다 어둡게.
  final int? accent;
  final bool helmet;
  final bool backpack;
  final bool tie;
  final bool sunglasses;
  final bool messyHair;

  /// 귀를 덮는 헤드셋(정면 실루엣).
  final bool headset;
}

const characterLooks = <String, CharacterLook>{
  // Soldier 1: 초록 군복, 헬멧, 갈색 배낭
  'basic': CharacterLook(
    skin: 0xFFF1C27D,
    hair: 0xFF4E3B2A,
    top: 0xFF3E7A3A,
    pants: 0xFF34502F,
    shoes: 0xFF3B2F25,
    accent: 0xFFB07A3E,
    helmet: true,
    backpack: true,
  ),
  // Hitman 1: 검은 정장, 흰 셔츠, 넥타이, 선글라스
  'marksman': CharacterLook(
    skin: 0xFFF6CDA3,
    hair: 0xFF1E1E22,
    top: 0xFF26272C,
    pants: 0xFF1D1E22,
    shoes: 0xFF111114,
    accent: 0xFFB8322C,
    tie: true,
    sunglasses: true,
  ),
  // Survivor 1: 파란 옷, 갈색 덥수룩한 머리, 가방끈
  'scout': CharacterLook(
    skin: 0xFFE8B48A,
    hair: 0xFF6B4A33,
    top: 0xFF4E6FB0,
    pants: 0xFF6B5A44,
    shoes: 0xFF3C3027,
    accent: 0xFF8B6A3E,
    backpack: true,
    messyHair: true,
  ),
  // Man Brown: 주황빛 갈색 옷, 짧은 갈색 머리(정면은 헤드셋)
  'assault': CharacterLook(
    skin: 0xFFE0A57A,
    hair: 0xFF5A3A22,
    top: 0xFFC77B38,
    pants: 0xFF6E4A2C,
    shoes: 0xFF3A2A1E,
    accent: 0xFF8E5426,
    headset: true,
  ),
};

/// 모르는 id는 기본 병사.
CharacterLook characterLook(String? id) =>
    characterLooks[id] ?? characterLooks['basic']!;
