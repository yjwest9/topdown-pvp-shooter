import 'package:firebase_database/firebase_database.dart';

import 'firebase_setup.dart';

/// 쓰는 값 안에 넣으면 서버가 서버 시간(ms)으로 바꾼다. (= `ServerValue.timestamp`)
const serverTimestamp = <String, String>{'.sv': 'timestamp'};

/// 쓰는 값 안에 넣으면 서버가 지금 값 + [delta]로 바꾼다. (= `ServerValue.increment`)
Map<String, Object> serverIncrement(int delta) => {
  '.sv': {'increment': delta},
};

/// 트랜잭션 함수가 이걸 돌려주면 아무것도 쓰지 않고 끝낸다.
const txAbort = _TxAbort();

class _TxAbort {
  const _TxAbort();
}

/// Realtime Database 경로 단위 읽기·쓰기. 경로는 `rooms/1234/meta`처럼 쓴다.
abstract class RtdbService {
  Future<Object?> get(String path);
  Future<void> set(String path, Object? value);
  Future<void> update(String path, Map<String, Object?> value);
  Future<void> remove(String path);

  /// 자동 id 자식으로 추가.
  Future<void> push(String path, Object? value);

  /// [push]가 쓰는 것과 같은 새 자동 id(쓰지는 않음).
  String newKey(String path);

  /// [update]가 지금 값으로 새 값을 만든다([txAbort]면 중단). 서버 값이 바뀌어 있으면
  /// 다시 부른다. [value]는 끝났을 때 값.
  /// [applyLocally]가 false면 서버가 확인하기 전엔 이 기기의 화면·캐시에도 값이 반영되지 않는다.
  Future<({bool committed, Object? value})> transaction(
    String path,
    Object? Function(Object? current) update, {
    bool applyLocally = true,
  });

  /// 지금 값을 한 번 보내고, 바뀔 때마다 보낸다.
  Stream<Object?> watch(String path);

  /// 자식이 추가될 때마다 그 값(처음엔 이미 있는 자식들).
  Stream<Object?> childAdded(String path);

  /// 접속이 끊기면 서버가 대신 실행.
  Future<void> setOnDisconnect(String path, Object? value);
  Future<void> removeOnDisconnect(String path);

  /// [path]와 그 아래에 걸어 둔 내 onDisconnect를 모두 취소.
  Future<void> cancelOnDisconnect(String path);

  /// 연결을 한 번 끊었다가 다시 붙인다(`goOffline` → `goOnline`). 쌓인 쓰기·리스너는 그대로.
  Future<void> reconnect();
}

class FirebaseRtdbService implements RtdbService {
  DatabaseReference _ref(String path) => rtdb.ref(path);

  @override
  Future<Object?> get(String path) async => (await _ref(path).get()).value;

  @override
  Future<void> set(String path, Object? value) => _ref(path).set(value);

  @override
  Future<void> update(String path, Map<String, Object?> value) =>
      _ref(path).update(value);

  @override
  Future<void> remove(String path) => _ref(path).remove();

  @override
  Future<void> push(String path, Object? value) => _ref(path).push().set(value);

  @override
  String newKey(String path) => _ref(path).push().key!;

  @override
  Future<({bool committed, Object? value})> transaction(
    String path,
    Object? Function(Object? current) update, {
    bool applyLocally = true,
  }) async {
    final r = await _ref(path).runTransaction((current) {
      final next = update(current);
      return identical(next, txAbort)
          ? Transaction.abort()
          : Transaction.success(next);
    }, applyLocally: applyLocally);
    return (committed: r.committed, value: r.snapshot.value);
  }

  @override
  Stream<Object?> watch(String path) =>
      _ref(path).onValue.map((e) => e.snapshot.value);

  @override
  Stream<Object?> childAdded(String path) =>
      _ref(path).onChildAdded.map((e) => e.snapshot.value);

  @override
  Future<void> setOnDisconnect(String path, Object? value) =>
      _ref(path).onDisconnect().set(value);

  @override
  Future<void> removeOnDisconnect(String path) =>
      _ref(path).onDisconnect().remove();

  @override
  Future<void> reconnect() async {
    await rtdb.goOffline();
    // 바로 다시 켜면 SDK가 끄기를 못 알아채는 경우가 있어서 잠깐 둔다.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await rtdb.goOnline();
  }

  @override
  Future<void> cancelOnDisconnect(String path) =>
      _ref(path).onDisconnect().cancel();
}
