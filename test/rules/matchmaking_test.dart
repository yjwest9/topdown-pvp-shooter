import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/matchmaking.dart';

void main() {
  const now = 100000;

  test('empty slot → claim', () {
    expect(decideQuickMatch(null, 'me', now), QuickMatchAction.claim);
  });

  test('stale slot (older than the limit) → claim, even if taken', () {
    expect(
      decideQuickMatch(
        (uid: 'x', t: now - quickMatchStaleMs - 1, takenBy: 'y'),
        'me',
        now,
      ),
      QuickMatchAction.claim,
    );
  });

  test('slot exactly at the limit is still alive', () {
    expect(
      decideQuickMatch(
        (uid: 'x', t: now - quickMatchStaleMs, takenBy: null),
        'me',
        now,
      ),
      QuickMatchAction.take,
    );
  });

  test('my own slot → wait', () {
    expect(
      decideQuickMatch((uid: 'me', t: now, takenBy: null), 'me', now),
      QuickMatchAction.wait,
    );
  });

  test("someone else's free slot → take", () {
    expect(
      decideQuickMatch((uid: 'x', t: now - 1000, takenBy: null), 'me', now),
      QuickMatchAction.take,
    );
  });

  test('slot already taken by someone → retry', () {
    expect(
      decideQuickMatch((uid: 'x', t: now, takenBy: 'y'), 'me', now),
      QuickMatchAction.retry,
    );
  });

  test('timings: heartbeat is well inside the stale limit', () {
    expect(quickMatchHeartbeat.inMilliseconds * 2, lessThan(quickMatchStaleMs));
  });
}
