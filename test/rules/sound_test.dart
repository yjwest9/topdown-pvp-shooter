import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/sound.dart';

void main() {
  const fireSounds = {
    Sfx.fireRifle,
    Sfx.fireSniper,
    Sfx.fireShotgun,
    Sfx.firePistol,
  };

  test('every sound key has its file in assets/audio', () {
    for (final s in Sfx.values) {
      expect(
        File('assets/audio/${s.file}').existsSync(),
        isTrue,
        reason: '${s.name} → assets/audio/${s.file}',
      );
    }
  });

  test('assets/audio is registered in pubspec (else the app is silent)', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/audio/'),
    );
  });

  test('every file in assets/audio is credited in CREDITS.md', () {
    final credits = File('assets/audio/CREDITS.md').readAsStringSync();
    final files = Directory('assets/audio')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n != 'CREDITS.md');
    expect(files, isNotEmpty);
    for (final f in files) {
      expect(credits, contains(f), reason: '$f is not in CREDITS.md');
    }
  });

  test('every weapon maps to one of the 4 fire sounds', () {
    expect(weapons, hasLength(11));
    for (final w in weapons) {
      expect(fireSounds, contains(fireSfxFor(w.family)), reason: w.id);
    }
  });

  test('fire sound follows the weapon family, not the weapon', () {
    expect(fireSfxFor(rifleHeavy.family), Sfx.fireRifle); // 중기관총형도 라이플
    expect(fireSfxFor(sniperBolt.family), Sfx.fireSniper);
    expect(fireSfxFor(shotgunDouble.family), Sfx.fireShotgun);
    expect(fireSfxFor(pistol.family), Sfx.firePistol);
  });

  test('enemy shots are half as loud as mine', () {
    expect(enemyShotVolume, 0.5);
  });
}
