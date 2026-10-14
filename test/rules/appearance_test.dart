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

  test(
    'every image the game loads is a real file, and none is left unused',
    () {
      final missing = [
        for (final f in artFiles)
          if (!File('assets/images/$f').existsSync()) f,
      ];
      expect(missing, isEmpty);
      // 병사는 코드로 그린다(decisions 8장). 폴더에는 맵 타일만 남는다.
      final pngs = Directory('assets/images')
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith('.png'));
      expect(pngs.toSet(), artFiles.toSet());
    },
  );

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
