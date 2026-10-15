import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/repositories/connection_repository.dart';
import 'package:topsoldier/rules/balance.dart';

import '../../fakes.dart';

void main() {
  testWidgets('connected: true at once, no reconnect', (tester) async {
    final db = FakeRtdbService();
    expect(await ConnectionRepository(db).ensureConnected(), true);
    expect(db.reconnects, 0);
  });

  testWidgets('not connected → one reconnect → connected: true', (
    tester,
  ) async {
    final db = FakeRtdbService()..connected = false;
    db.onReconnect = () => db.setConnected(true);
    expect(await ConnectionRepository(db).ensureConnected(), true);
    expect(db.reconnects, 1);
  });

  testWidgets('not connected and it stays so: false after connectWait, '
      'reconnect tried once', (tester) async {
    final db = FakeRtdbService()..connected = false;
    final f = ConnectionRepository(db).ensureConnected();
    await tester.pump(connectWait + const Duration(seconds: 1));
    expect(await f, false);
    expect(db.reconnects, 1);
  });

  testWidgets('reconnect that takes a second still counts', (tester) async {
    final db = FakeRtdbService()..connected = false;
    final repo = ConnectionRepository(db);
    final f = repo.ensureConnected();
    await tester.pump(const Duration(seconds: 1));
    db.setConnected(true);
    await tester.pump();
    expect(await f, true);
  });
}
