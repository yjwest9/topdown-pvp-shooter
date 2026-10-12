import 'dart:async';

import 'rtdb_service.dart';

/// 기기 안 메모리 RTDB(봇전용, decisions 12장). 서버 시간 = 내 시계, 접속 끊김 없음.
/// 바뀐 값은 실제 DB처럼 비동기로 알린다(듣는 쪽이 그 안에서 또 써도 되게).
// ponytail: test/fakes.dart의 FakeRtdbService와 구조가 같다. 그쪽은 동기 알림 + 테스트 훅이 필요해서 따로 둠.
class LocalRtdbService implements RtdbService {
  final _root = <String, Object?>{};
  final _changed = StreamController<void>.broadcast();
  int _pushId = 0;

  Object? _read(String path) {
    Object? node = _root;
    for (final p in path.split('/')) {
      if (node is! Map) return null;
      node = node[p];
    }
    return node;
  }

  Object? _resolve(Object? v) => switch (v) {
    {'.sv': 'timestamp'} => DateTime.now().millisecondsSinceEpoch,
    Map<Object?, Object?>() => <String, Object?>{
      for (final e in v.entries) e.key! as String: _resolve(e.value),
    },
    _ => v,
  };

  void _write(String path, Object? value) {
    final parts = path.split('/');
    var node = _root;
    for (final p in parts.take(parts.length - 1)) {
      node = (node[p] ??= <String, Object?>{}) as Map<String, Object?>;
    }
    if (value == null) {
      node.remove(parts.last);
    } else {
      node[parts.last] = _resolve(value);
    }
  }

  @override
  Future<Object?> get(String path) async => _read(path);

  @override
  Future<void> set(String path, Object? value) async {
    _write(path, value);
    _changed.add(null);
  }

  @override
  Future<void> update(String path, Map<String, Object?> value) async {
    for (final e in value.entries) {
      _write('$path/${e.key}', e.value);
    }
    _changed.add(null);
  }

  @override
  Future<void> remove(String path) => set(path, null);

  @override
  Future<void> push(String path, Object? value) =>
      set('$path/${newKey(path)}', value);

  @override
  String newKey(String path) => 'id${_pushId++}';

  @override
  Future<({bool committed, Object? value})> transaction(
    String path,
    Object? Function(Object? current) update,
  ) async {
    final next = update(_read(path));
    if (identical(next, txAbort)) return (committed: false, value: _read(path));
    await set(path, next);
    return (committed: true, value: _read(path));
  }

  @override
  Stream<Object?> watch(String path) => Stream.multi((c) {
    c.add(_read(path));
    final sub = _changed.stream.listen((_) => c.add(_read(path)));
    c.onCancel = sub.cancel;
  });

  @override
  Stream<Object?> childAdded(String path) => Stream.multi((c) {
    final seen = <Object?>{};
    void emitNew() {
      final m = _read(path);
      if (m is! Map) return;
      for (final e in m.entries) {
        if (seen.add(e.key)) c.add(e.value);
      }
    }

    emitNew();
    final sub = _changed.stream.listen((_) => emitNew());
    c.onCancel = sub.cancel;
  });

  @override
  Future<void> setOnDisconnect(String path, Object? value) async {}

  @override
  Future<void> removeOnDisconnect(String path) async {}

  @override
  Future<void> cancelOnDisconnect(String path) async {}
}
