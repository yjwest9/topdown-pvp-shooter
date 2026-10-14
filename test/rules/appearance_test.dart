import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/appearance.dart';
import 'package:topsoldier/rules/balance.dart';

void main() {
  group('pose follows the weapon (decisions 3장)', () {
    test('rifles, M249 and shotguns hold the machine pose', () {
      for (final w in weapons) {
        if (w.family == WeaponFamily.rifle ||
            w.family == WeaponFamily.shotgun) {
          expect(poseFor(w.family), Pose.machine, reason: w.id);
        }
      }
    });
    test('sniper rifles → silencer, pistol → gun', () {
      expect(poseFor(WeaponFamily.sniper), Pose.silencer);
      expect(poseFor(WeaponFamily.pistol), Pose.gun);
    });
    test('reloading is always the reload pose', () {
      for (final f in WeaponFamily.values) {
        expect(poseFor(f, reloading: true), Pose.reload);
      }
    });
  });

  test('characters map to the Kenney sprites decided in decisions 8장', () {
    expect(
      {for (final c in characters) c.id: characterSprite(c.id, Pose.stand)},
      {
        'basic': 'soldier1_stand.png',
        'marksman': 'hitman1_stand.png',
        'scout': 'survivor1_stand.png',
        'assault': 'manBrown_stand.png',
      },
    );
    // 모르는 id는 기본 병사 그림.
    expect(characterSprite('nope', Pose.gun), 'soldier1_gun.png');
  });

  test('every character × every pose used, and every tile, is a real file', () {
    final missing = [
      for (final f in artFiles)
        if (!File('assets/images/$f').existsSync()) f,
    ];
    expect(missing, isEmpty);
    // 모든 캐릭터 × 모든 무기 종류(재장전 포함)가 목록에 있다.
    for (final c in characters) {
      for (final family in WeaponFamily.values) {
        for (final reloading in [false, true]) {
          expect(
            artFiles,
            contains(
              characterSprite(c.id, poseFor(family, reloading: reloading)),
            ),
          );
        }
      }
      expect(artFiles, contains(characterSprite(c.id, Pose.stand)));
    }
  });

  test('the license file and the asset folder are in place', () {
    expect(File('assets/images/LICENSE-kenney.txt').existsSync(), true);
    expect(File('pubspec.yaml').readAsStringSync(), contains('assets/images/'));
  });

  group('weapon looks (decisions 17장: 무기마다 코드로 그림)', () {
    test('every weapon has its own look, no two alike', () {
      final looks = [for (final w in weapons) weaponLook(w.id)];
      expect(looks.toSet(), hasLength(weapons.length));
      for (final w in weapons) {
        expect(weaponLooks.containsKey(w.id), true, reason: w.id);
      }
    });
    test('family shapes: pistol is a pistol, double barrel has two, snipers scoped', () {
      expect(weaponLook('pistol').pistol, true);
      expect(weaponLook('shotgun_double').barrels, 2);
      for (final w in weapons.where((w) => w.family == WeaponFamily.sniper)) {
        expect(weaponLook(w.id).optic, isNot(Optic.none), reason: w.id);
      }
    });
  });

  test('every character has a front look (홈·캐릭터 화면, decisions 8장)', () {
    for (final c in characters) {
      expect(characterLooks.containsKey(c.id), true, reason: c.id);
    }
    expect(characterLook('nope'), characterLook('basic'));
    expect(characterLook('basic').helmet, true);
    expect(characterLook('marksman').sunglasses, true);
  });
}
