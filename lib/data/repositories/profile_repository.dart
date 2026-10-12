import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import '../services/rtdb_service.dart';
import 'auth_repository.dart';

final profileRepositoryProvider = Provider(
  (ref) => ProfileRepository(FirebaseRtdbService()),
);

/// 내 프로필. null이면 아직 없음(첫 실행 → 닉네임 입력). 로그인 실패(오프라인 등)면 에러.
final profileProvider = StreamProvider<Profile?>((ref) async* {
  final uid = await ref.read(authRepositoryProvider).signIn();
  yield* ref.read(profileRepositoryProvider).watch(uid);
});

/// 방·매칭에 쓸 내 닉네임. 프로필을 아직 못 읽었으면 임시 닉네임.
String myNickname(Ref ref) =>
    ref.read(profileProvider).value?.nickname ??
    ref.read(authRepositoryProvider).nickname;

/// `users/{uid}` 읽기·쓰기(decisions 13장). 본인 것만(DB 규칙).
class ProfileRepository {
  ProfileRepository(this._db);

  final RtdbService _db;

  String _user(String uid) => 'users/$uid';

  Stream<Profile?> watch(String uid) =>
      _db.watch(_user(uid)).map((v) => v == null ? null : Profile.fromJson(v));

  Future<void> create(String uid, String nickname) => _db.set(_user(uid), {
    ...Profile(nickname: nickname).toJson(),
    'createdAt': serverTimestamp,
  });

  Future<void> setNickname(String uid, String nickname) =>
      _db.update(_user(uid), {'nickname': nickname});

  /// 매치 결과를 트랜잭션으로 더한다. [matchId]가 이미 반영됐거나 프로필이 없으면
  /// 아무것도 안 하고 null. 아니면 [apply]가 만든 새 프로필로 바꾸고 전후 값.
  Future<({Profile before, Profile after})?> applyMatch(
    String uid,
    String matchId,
    Profile Function(Profile current) apply,
  ) async {
    ({Profile before, Profile after})? change;
    await _db.transaction(_user(uid), (cur) {
      change = null;
      // 로컬에 아직 값이 없을 수 있다. null을 그대로 돌려주면 서버 값으로 다시 불린다.
      if (cur == null) return null;
      final before = Profile.fromJson(cur);
      if (before.lastMatchId == matchId) return txAbort;
      final after = apply(before).copyWith(lastMatchId: matchId);
      change = (before: before, after: after);
      return {...(cur as Map<Object?, Object?>), ...after.toJson()};
    });
    return change;
  }
}
