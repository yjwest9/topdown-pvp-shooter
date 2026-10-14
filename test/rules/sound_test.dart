import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/sound.dart';

void main() {
  test('every sound has its file in assets/audio', () {
    expect(allSounds, isNotEmpty);
    for (final s in allSounds) {
      expect(
        File('assets/audio/${s.file}').existsSync(),
        isTrue,
        reason: 'assets/audio/${s.file}',
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

  test('no leftover sound files that nothing plays', () {
    final used = {for (final s in allSounds) s.file};
    final files = Directory('assets/audio')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('.ogg'));
    for (final f in files) {
      expect(used, contains(f), reason: '$f is not used');
    }
  });

  test('all 11 weapons have their own fire sound', () {
    expect(weapons, hasLength(11));
    final files = {for (final w in weapons) fireSound(w)};
    expect(files, hasLength(11)); // 같은 종류(라이플 4종 등)끼리도 다름
    expect(fireSound(rifleHeavy), 'fire_rifle_heavy.ogg');
  });

  test('reload sound is one per weapon family', () {
    final files = {for (final f in WeaponFamily.values) reloadSound(f)};
    expect(files, hasLength(WeaponFamily.values.length));
    expect(reloadSound(rifleHeavy.family), reloadSound(rifleStandard.family));
    expect(reloadSound(sniperBolt.family), isNot(reloadSound(pistol.family)));
  });

  test('enemy shots are half as loud as mine', () {
    expect(enemyShotVolume, 0.5);
  });
}
