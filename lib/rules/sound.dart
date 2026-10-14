import 'balance.dart';

/// 효과음 종류(decisions 17장). 파일은 `assets/audio/`, 출처는 `CREDITS.md`.
enum Sfx {
  fireRifle('fire_rifle.ogg', voices: 6),
  fireSniper('fire_sniper.ogg', voices: 2),
  fireShotgun('fire_shotgun.ogg', voices: 3),
  firePistol('fire_pistol.ogg', voices: 3),
  reload('reload.ogg', voices: 2),

  /// 내 총알이 맞힘.
  hit('hit.ogg', voices: 3),
  kill('kill.ogg', voices: 1),

  /// 내가 맞음.
  hurt('hurt.ogg', voices: 2),
  win('win.ogg', voices: 1),
  lose('lose.ogg', voices: 1);

  const Sfx(this.file, {required this.voices});

  final String file;

  /// 겹쳐 울릴 수 있게 미리 만들어 두는 재생기 수(연사해도 소리가 끊기지 않게).
  final int voices;
}

/// 사격 소리는 무기가 아니라 종류(family)로 고른다. M249(중기관총형)도 라이플.
Sfx fireSfxFor(WeaponFamily family) => switch (family) {
  WeaponFamily.rifle => Sfx.fireRifle,
  WeaponFamily.sniper => Sfx.fireSniper,
  WeaponFamily.shotgun => Sfx.fireShotgun,
  WeaponFamily.pistol => Sfx.firePistol,
};
