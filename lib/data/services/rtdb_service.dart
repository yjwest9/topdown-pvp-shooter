import 'package:firebase_database/firebase_database.dart';

import 'firebase_setup.dart';

/// 쓰는 값 안에 넣으면 서버가 서버 시간(ms)으로 바꾼다. (= `ServerValue.timestamp`)
const serverTimestamp = <String, String>{'.sv': 'timestamp'};

/// Realtime Database 경로 단위 읽기·쓰기. 경로는 `rooms/1234/meta`처럼 쓴다.
abstract class RtdbService {
  Future<Object?> get(String path);
  Future<void> set(String path, Object? value);
  Future<void> update(String path, Map<String, Object?> value);
  Future<void> remove(String path);

  /// 자동 id 자식으로 추가.
  Future<void> push(String path, Object? value);

  /// [path]가 비어 있을 때만 쓴다(트랜잭션). 썼으면 true.
  Future<bool> setIfAbsent(String path, Object? value);

  /// 지금 값을 한 번 보내고, 바뀔 때마다 보낸다.
  Stream<Object?> watch(String path);

  /// 자식이 추가될 때마다 그 값(처음엔 이미 있는 자식들).
  Stream<Object?> childAdded(String path);

  /// 접속이 끊기면 서버가 대신 실행.
  Future<void> setOnDisconnect(String path, Object? value);
  Future<void> removeOnDisconnect(String path);
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
  Future<bool> setIfAbsent(String path, Object? value) async {
    final result = await _ref(path).runTransaction(
      (current) =>
          current == null ? Transaction.success(value) : Transaction.abort(),
      applyLocally: false,
    );
    return result.committed;
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
}
