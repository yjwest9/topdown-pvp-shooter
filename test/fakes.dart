import 'dart:async';

import 'package:topsoldier/data/services/auth_service.dart';
import 'package:topsoldier/data/services/rtdb_service.dart';

class FakeAuthService implements AuthService {
  FakeAuthService(this.uid);
  final String uid;

  @override
  Future<String> signInAnonymously() async => uid;
}

/// 메모리 안 RTDB. 바뀐 값은 동기로 전달(위젯 테스트의 가짜 시간 밖으로 새지 않게). 경로는 '/'로 나눈 중첩 Map. [serverTime]이 서버 시간 역할.
class FakeRtdbService implements RtdbService {
  final root = <String, Object?>{};
  int serverTime = 1000;
  int _pushId = 0;
  final _changed = StreamController<void>.broadcast(sync: true);

  /// 끊길 때 할 일. 테스트에선 [disconnect]로 실행.
  final onDisconnect = <String, Object?>{};

  /// 경로별 set·push 횟수.
  final writes = <String, int>{};

  List<String> _parts(String path) => path.split('/');

  Object? _read(String path) {
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

  void _write(String path, Object? value) {
    final parts = _parts(path);
    var node = root;
    for (final p in parts.take(parts.length - 1)) {
      node = (node[p] ??= <String, Object?>{}) as Map<String, Object?>;
    }
    if (value == null) {
      node.remove(parts.last);
    } else {
      node[parts.last] = _resolve(value);
    }
    writes[path] = (writes[path] ?? 0) + 1;
    _changed.add(null);
  }

  /// 접속 끊김: onDisconnect 작업 실행.
  void disconnect() {
    onDisconnect.forEach(_write);
    onDisconnect.clear();
  }

  @override
  Future<Object?> get(String path) async => _read(path);

  /// 있으면 set이 이게 끝날 때까지 안 끝난다(응답 없는 서버 흉내).
  Completer<void>? hold;

  @override
  Future<void> set(String path, Object? value) async {
    _write(path, value);
    await hold?.future;
  }

  @override
  Future<void> update(String path, Map<String, Object?> value) async {
    for (final e in value.entries) {
      _write('$path/${e.key}', e.value);
    }
  }

  @override
  Future<void> remove(String path) async => _write(path, null);

  @override
  Future<void> push(String path, Object? value) async =>
      _write('$path/id${_pushId++}', value);

  @override
  Future<bool> setIfAbsent(String path, Object? value) async {
    if (_read(path) != null) return false;
    _write(path, value);
    return true;
  }

  @override
  Stream<Object?> watch(String path) => Stream.multi((c) {
    c.add(_read(path));
    final sub = _changed.stream.listen((_) => c.addSync(_read(path)));
    c.onCancel = sub.cancel;
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
    c.onCancel = sub.cancel;
  });

  @override
  Future<void> setOnDisconnect(String path, Object? value) async =>
      onDisconnect[path] = value;

  @override
  Future<void> removeOnDisconnect(String path) async =>
      onDisconnect[path] = null;
}
