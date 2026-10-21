import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/map_select.dart';

void main() {
  test('meta map value picks the map: duel, outpost', () {
    expect(mapById('duel'), duelMap);
    expect(mapById('outpost'), outpostMap);
  });

  test('unknown or missing meta map falls back to duel', () {
    for (final v in <Object?>[null, '', 'frontline', 'Outpost', 3]) {
      expect(mapById(v), duelMap, reason: '$v');
    }
  });

  test('selectable maps: duel first (default), labels show the size', () {
    expect(selectableMaps, [duelMap, outpostMap]);
    expect(duelMap.label, 'duel 17×17');
    expect(outpostMap.label, 'outpost 31×31');
  });
}
