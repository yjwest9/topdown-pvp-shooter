import 'dart:async';

import 'package:topsoldier/data/services/ad_service.dart';
import 'package:topsoldier/data/services/auth_service.dart';
import 'package:topsoldier/data/services/rtdb_service.dart';
import 'package:topsoldier/data/services/sound_service.dart';

class FakeAuthService implements AuthService {
  FakeAuthService(this.uid, {this.linkResult = GoogleLink.linked});
  String uid;
  GoogleLink linkResult;

  /// [GoogleLink.exists]일 때 바꿔 들어갈 계정의 uid.
  String existingUid = 'google-uid';

  @override
  String? googleEmail;

  @override
  Future<String> signInAnonymously() async => uid;

  @override
  Future<GoogleLink> linkGoogle() async {
    if (linkResult == GoogleLink.linked) googleEmail = 'me@gmail.com';
    return linkResult;
  }

  @override
  Future<String> switchToGoogle() async {
    googleEmail = 'me@gmail.com';
    return uid = existingUid;
  }
}

/// 구글 연결을 쓰지 않는 가짜 로그인용.
mixin NoGoogleAuth {
  String? get googleEmail => null;
  Future<GoogleLink> linkGoogle() async => GoogleLink.cancelled;
  Future<String> switchToGoogle() async => throw UnimplementedError();
}

/// 광고 SDK 대신. [earn]이 false면 광고를 중간에 닫은 것.
class FakeAdService implements AdService {
  FakeAdService({this.supported = true, this.loads = true, this.earn = true});

  @override
  final bool supported;
  bool loads;
  bool earn;
  int shown = 0;
  int loadCalls = 0;

  /// 광고를 보는 도중에 일어나는 일(예: 네트워크 끊김).
  void Function()? onShow;

  @override
  Future<bool> load() async {
    loadCalls++;
    return supported && loads;
  }

  @override
  Future<bool> show() async {
    shown++;
    onShow?.call();
    return earn;
  }
}

/// 소리를 내는 대신 어떤 파일을 어떤 볼륨으로 냈는지 기록한다.
class FakeSoundService implements SoundService {
  final plays = <({String file, double volume})>[];

  List<String> get files => [for (final p in plays) p.file];

  @override
  Future<void> load(Iterable<({String file, int voices})> files) async {}

  @override
  Future<void> play(String file, double volume) async =>
      plays.add((file: file, volume: volume));
}

/// 메모리 안 RTDB. 바뀐 값은 동기로 전달(위젯 테스트의 가짜 시간 밖으로 새지 않게). 경로는 '/'로 나눈 중첩 Map. [serverTime]이 서버 시간 역할.
class FakeRtdbService implements RtdbService {
  final root = <String, Object?>{};
  int serverTime = 1000;
  int _pushId = 0;
  var _changed = StreamController<void>.broadcast(sync: true);

  /// 테스트 사이 초기화. 이전 테스트의 구독은 더 이상 이벤트를 받지 않는다.
  void reset() {
    root.clear();
    writes.clear();
    onDisconnect.clear();
    serverTime = 1000;
    hold = null;
    rerunTransactions = false;
    _changed = StreamController<void>.broadcast(sync: true);
  }

  /// 끊길 때 할 일. 테스트에선 [disconnect]로 실행.
  final onDisconnect = <String, Object?>{};

  /// 경로별 set·push 횟수.
  final writes = <String, int>{};

  List<String> _parts(String path) => path.split('/');

  /// `.info/connected`(DB 연결 상태). [setConnected]로 바꾼다.
  bool connected = true;

  /// [reconnect] 때마다 불린다(재연결로 붙는 것 흉내: 안에서 [setConnected]).
  void Function()? onReconnect;
  int reconnects = 0;

  void setConnected(bool value) {
    connected = value;
    _changed.add(null);
  }

  @override
  Future<void> reconnect() async {
    reconnects++;
    onReconnect?.call();
  }

  Object? _read(String path) {
    if (path == '.info/connected') return connected;
    Object? node = root;
    for (final p in _parts(path)) {
      if (node is! Map) return null;
      node = node[p];
    }
    return node;
  }

  Object? _resolve(Object? v) => switch (v) {
    {'.sv': 'timestamp'} => serverTime,
    Map<Object?, Object?>() => <String, Object?>{
      for (final e in v.entries) e.key! as String: _resolve(e.value),
    },
    _ => v,
  };

  void _write(String path, Object? value, {bool notify = true}) {
    final parts = _parts(path);
    var node = root;
    for (final p in parts.take(parts.length - 1)) {
      node = (node[p] ??= <String, Object?>{}) as Map<String, Object?>;
    }
    if (value case {'.sv': {'increment': final num delta}}) {
      value = ((node[parts.last] as num?) ?? 0) + delta;
    }
    if (value == null) {
      node.remove(parts.last);
    } else {
      node[parts.last] = _resolve(value);
    }
    writes[path] = (writes[path] ?? 0) + 1;
    if (notify) _changed.add(null);
  }

  /// 접속 끊김: onDisconnect 작업 실행.
  void disconnect() {
    onDisconnect.forEach(_write);
    onDisconnect.clear();
  }

  @override
  Future<Object?> get(String path) async => _read(path);

  /// 있으면 트랜잭션이 이게 끝날 때까지 안 끝난다(오프라인 흉내).
  Completer<void>? holdTransactions;

  /// 있으면 트랜잭션이 이 예외로 실패한다(DB 규칙 거부 등).
  Object? transactionError;

  /// 있으면 set이 이게 끝날 때까지 안 끝난다(응답 없는 서버 흉내).
  Completer<void>? hold;

  @override
  Future<void> set(String path, Object? value) async {
    _write(path, value);
    await hold?.future;
  }

  @override
  Future<void> update(String path, Map<String, Object?> value) async {
    // 실제 RTDB처럼 한 번에 적용하고 한 번만 알린다.
    for (final e in value.entries) {
      _write('$path/${e.key}', e.value, notify: false);
    }
    _changed.add(null);
  }

  @override
  Future<void> remove(String path) async => _write(path, null);

  @override
  Future<void> push(String path, Object? value) async =>
      _write('$path/${newKey(path)}', value);

  @override
  String newKey(String path) => 'id${_pushId++}';

  /// true면 트랜잭션 함수를 두 번 부른다(서버 값이 달라 다시 도는 경우 흉내). 쓰기는 마지막 결과만.
  bool rerunTransactions = false;

  @override
  Future<({bool committed, Object? value})> transaction(
    String path,
    Object? Function(Object? current) update, {
    bool applyLocally = true,
  }) async {
    if (transactionError != null) throw transactionError!;
    // 연결이 없으면 트랜잭션은 서버가 답할 때까지 값을 바꾸지 않는다(applyLocally: false).
    if (holdTransactions != null) await holdTransactions!.future;
    if (rerunTransactions) update(_read(path));
    final next = update(_read(path));
    if (identical(next, txAbort)) return (committed: false, value: _read(path));
    _write(path, next);
    return (committed: true, value: _read(path));
  }

  @override
  Stream<Object?> watch(String path) => Stream.multi((c) {
    c.add(_read(path));
    final sub = _changed.stream.listen((_) => c.addSync(_read(path)));
    // Future를 돌려주면 .first가 루트 존의 취소 완료를 기다려서 가짜 시간(testWidgets) 안에서 안 끝난다.
    c.onCancel = () => unawaited(sub.cancel());
  });

  @override
  Stream<Object?> childAdded(String path) => Stream.multi((c) {
    final seen = <Object?>{};
    void emitNew() {
      final m = _read(path);
      if (m is! Map) return;
      for (final e in m.entries) {
        if (seen.add(e.key)) c.addSync(e.value);
      }
    }

    emitNew();
    final sub = _changed.stream.listen((_) => emitNew());
    // Future를 돌려주면 .first가 루트 존의 취소 완료를 기다려서 가짜 시간(testWidgets) 안에서 안 끝난다.
    c.onCancel = () => unawaited(sub.cancel());
  });

  @override
  Future<void> setOnDisconnect(String path, Object? value) async =>
      onDisconnect[path] = value;

  @override
  Future<void> removeOnDisconnect(String path) async =>
      onDisconnect[path] = null;

  /// 클라이언트 구분이 없어서 다른 사람이 건 것도 같이 지운다.
  @override
  Future<void> cancelOnDisconnect(String path) async =>
      onDisconnect.removeWhere((k, _) => k == path || k.startsWith('$path/'));
}

/// 로그인이 안 되는 것(오프라인). 예외 문구는 firebase 원문처럼 영어.
class OfflineAuthService with NoGoogleAuth implements AuthService {
  @override
  Future<String> signInAnonymously() async => throw Exception(
    '[firebase_auth/unknown] An internal error has occurred. '
    '[ Failed to connect to /10.0.2.2:9099',
  );
}

/// 처음 [failures]번은 로그인이 안 되고(오프라인), 그 뒤엔 된다(온라인 복귀).
class FlakyAuthService with NoGoogleAuth implements AuthService {
  FlakyAuthService(this.uid, {this.failures = 1});
  final String uid;
  int failures;

  @override
  Future<String> signInAnonymously() async {
    if (failures > 0) {
      failures--;
      throw Exception('offline');
    }
    return uid;
  }
}
