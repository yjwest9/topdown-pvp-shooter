import 'balance.dart';

/// 무기마다 다른 사격 소리(decisions 17장). 파일 이름이 무기 id를 따른다.
/// 칼은 전용 소리가 없어(CC0 원본을 못 구함) 맞힘 소리를 휘두를 때도 쓴다.
String fireSound(WeaponStats weapon) =>
    weapon.isMelee ? Sfx.hit.file : 'fire_${weapon.id}.ogg';

/// 재장전 소리는 종류별(라이플·저격·샷건·권총).
String reloadSound(WeaponFamily family) => 'reload_${family.name}.ogg';

/// 무기와 상관없는 효과음. 파일은 `assets/audio/`, 출처는 `CREDITS.md`.
enum Sfx {
  /// 내 총알이 맞힘.
  hit('hit.ogg', voices: 3),
  kill('kill.ogg', voices: 1),

  /// 내가 맞음.
  hurt('hurt.ogg', voices: 2),
  win('win.ogg', voices: 1),
  lose('lose.ogg', voices: 1);

  const Sfx(this.file, {required this.voices});

  final String file;

  /// 겹쳐 울릴 수 있게 미리 만들어 두는 재생기 수.
  final int voices;
}

/// 미리 불러 둘 모든 소리. 연사가 빠른 라이플은 재생기를 더 둔다(소리가 끊기지 않게).
final allSounds = <({String file, int voices})>[
  for (final w in weapons)
    // 칼은 소리가 아직 없다(효과음은 2부 이후).
    if (!w.isMelee)
      (file: fireSound(w), voices: w.family == WeaponFamily.rifle ? 6 : 3),
  for (final f in WeaponFamily.values)
    if (f != WeaponFamily.melee) (file: reloadSound(f), voices: 2),
  for (final s in Sfx.values) (file: s.file, voices: s.voices),
];
