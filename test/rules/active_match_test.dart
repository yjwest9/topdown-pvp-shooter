import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/active_match.dart';

void main() {
  test('no marker → nothing to do', () {
    expect(
      activeMatchAction(activeMatchId: null, lastMatchId: null),
      ActiveMatchAction.none,
    );
    expect(
      activeMatchAction(activeMatchId: null, lastMatchId: 'a-1'),
      ActiveMatchAction.none,
    );
  });

  test('marker left over from an unfinished match → record a loss', () {
    expect(
      activeMatchAction(activeMatchId: 'a-1', lastMatchId: null),
      ActiveMatchAction.recordLoss,
    );
    expect(
      activeMatchAction(activeMatchId: 'a-2', lastMatchId: 'a-1'),
      ActiveMatchAction.recordLoss,
    );
  });

  test(
    'that match was already saved → only clear the marker (no 2nd loss)',
    () {
      expect(
        activeMatchAction(activeMatchId: 'a-1', lastMatchId: 'a-1'),
        ActiveMatchAction.clearOnly,
      );
    },
  );
}
