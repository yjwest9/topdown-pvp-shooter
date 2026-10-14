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
