import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/loadout.dart';
import 'package:topsoldier/rules/profile.dart';

void main() {
  group('statBars', () {
    test('each bar is value / max of all weapons', () {
      final b = statBars(rifleStandard, weapons);
      // 데미지 최대는 더블배럴 110, 사거리 최대는 볼트액션 1100, 탄창 최대는 M249 80
      expect(b.damage, closeTo(13 / 110, 1e-9));
      expect(b.range, closeTo(560 / 1100, 1e-9));
      expect(b.magazine, closeTo(30 / 80, 1e-9));
      expect(b.mobility, 1.0);
      // 연사 속도 = 1 / 간격. 가장 빠른 건 FAMAS 0.07
      expect(b.fireRate, closeTo(0.07 / 0.11, 1e-9));
    });

    test('the best weapon in a stat gets a full bar, all bars in 0..1', () {
      expect(statBars(shotgunDouble, weapons).damage, 1.0);
      expect(statBars(sniperBolt, weapons).range, 1.0);
      expect(statBars(rifleHeavy, weapons).magazine, 1.0);
      expect(statBars(rifleRapid, weapons).fireRate, 1.0);
      for (final w in weapons) {
        final b = statBars(w, weapons);
        for (final v in [
          b.damage,
          b.fireRate,
          b.range,
          b.magazine,
          b.mobility,
        ]) {
          expect(v, inInclusiveRange(0, 1));
        }
      }
    });
  });

  group('record', () {
    test('win rate', () {
      expect(winRate(wins: 0, matches: 0), 0); // 0판
      expect(winRate(wins: 3, matches: 4), 0.75);
    });

    test('K/D (0 deaths → kills)', () {
      expect(kdRatio(kills: 0, deaths: 0), 0);
      expect(kdRatio(kills: 7, deaths: 0), 7);
      expect(kdRatio(kills: 9, deaths: 6), 1.5);
    });
  });

  test(
    'every weapon has a name, pros and cons; price only for non-starters',
    () {
      for (final w in weapons) {
        expect([w.name, w.pros, w.cons], everyElement(isNotEmpty));
        expect(weaponById(w.id), same(w));
      }
      expect(weaponById('nope'), isNull);
      expect(weaponPrice, 20000);
    },
  );
}
