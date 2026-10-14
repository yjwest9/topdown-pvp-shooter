import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/shop.dart';

void main() {
  group('adCooldownLeft (1시간, decisions 9장)', () {
    const now = 10000000000;
    Duration left(int? last) => adCooldownLeft(last, now);

    test('never watched → 0', () => expect(left(null), Duration.zero));
    test('just now → 60 minutes', () {
      expect(left(now), const Duration(minutes: 60));
    });
    test('3,599,999ms ago → 1ms', () {
      expect(left(now - 3599999), const Duration(milliseconds: 1));
    });
    test('exactly 3,600,000ms ago → 0', () {
      expect(left(now - 3600000), Duration.zero);
    });
    test('future value (clock skew) → never over 60 minutes', () {
      expect(left(now + 999999), const Duration(minutes: 60));
    });
  });

  group('exchangeGold (100,000G → 100다이아)', () {
    test('100,000G → 0G, +100', () {
      expect(exchangeGold(gold: 100000, diamond: 0), (gold: 0, diamond: 100));
    });
    test('250,000G → 150,000G, +100', () {
      expect(exchangeGold(gold: 250000, diamond: 30), (
        gold: 150000,
        diamond: 130,
      ));
    });
    test('99,999G → not enough gold (null), nothing changes', () {
      expect(exchangeGold(gold: 99999, diamond: 5), isNull);
    });
  });
}
