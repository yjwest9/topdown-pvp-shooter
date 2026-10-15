import 'package:flutter/foundation.dart';

import '../../rules/balance.dart';
import '../services/rtdb_service.dart';

/// DB 연결 상태(`.info/connected`)와 재연결(decisions 13장).
class ConnectionRepository {
  ConnectionRepository(this._db);

  final RtdbService _db;

  /// 연결되면 true, 끊기면 false. 지금 값을 바로 한 번 보낸다.
  Stream<bool> watch() =>
      _db.watch('.info/connected').map((v) => v == true).distinct();

  /// 연결이 돼 있으면 true. 아니면 재연결을 한 번 시도하고 [connectWait] 안에 안 붙으면 false.
  /// (네트워크가 돌아와도 앱이 스스로 다시 안 붙는 경우가 있어서 직접 붙인다.)
  Future<bool> ensureConnected() async {
    if (await watch().first) return true;
    debugPrint('DB 연결 안 됨 → 재연결');
    await _db.reconnect();
    return watch()
        .firstWhere((c) => c)
        .timeout(connectWait, onTimeout: () => false);
  }
}
