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

  // ---------------------------------------------------------- 무기 (6장)

  /// 로드아웃이 없으면(새 유저·기존 유저) 기본 무기 2개를 주고 장착한다. 이미 있으면 그대로.
  Future<void> grantStarter(
    String uid, {
    required String primary,
    required String secondary,
  }) async {
    final p = _db.newKey('${_user(uid)}/weapons');
    final s = _db.newKey('${_user(uid)}/weapons');
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(_user(uid), (cur) {
      if (cur == null) return null; // 서버 값으로 다시 불린다
      if (Profile.fromJson(cur).hasLoadout) return txAbort;
      final m = {...(cur as Map<Object?, Object?>)};
      m['weapons'] = {
        ...((m['weapons'] as Map<Object?, Object?>?) ?? const {}),
        p: OwnedWeapon(id: p, weaponId: primary).toJson(now),
        s: OwnedWeapon(id: s, weaponId: secondary).toJson(now),
      };
      m['loadout'] = {'primary': p, 'secondary': s};
      return m;
    });
  }

  /// [weaponId]를 [price] 골드에 산다. 골드 차감과 무기 생성은 트랜잭션 하나로.
  /// 골드가 모자라거나 이미 있으면 아무것도 안 바꾸고 false.
  Future<bool> buy(String uid, String weaponId, int price) async {
    final id = _db.newKey('${_user(uid)}/weapons');
    final now = DateTime.now().millisecondsSinceEpoch;
    var bought = false;
    await _db.transaction(_user(uid), (cur) {
      bought = false;
      if (cur == null) return null;
      final p = Profile.fromJson(cur);
      if (p.gold < price || p.owned(weaponId) != null) return txAbort;
      bought = true;
      final m = {...(cur as Map<Object?, Object?>)};
      m['gold'] = p.gold - price;
      m['weapons'] = {
        ...((m['weapons'] as Map<Object?, Object?>?) ?? const {}),
        id: OwnedWeapon(id: id, weaponId: weaponId).toJson(now),
      };
      return m;
    });
    return bought;
  }

  /// 강화 한 번. 성공 여부([success])는 밖에서 한 번만 굴려서 넘긴다(트랜잭션이 다시
  /// 돌아도 결과가 안 바뀌게). 골드가 [cost] 이상이고 그 무기가 아직 [fromLevel]일 때만
  /// 골드를 빼고, 성공이면 단계 +1. 조건이 안 맞으면(이미 강화됨·골드 부족) 아무것도
  /// 안 바꾸고 false.
  Future<bool> upgrade(
    String uid,
    String ownedId, {
    required int fromLevel,
    required int cost,
    required bool success,
  }) async {
    var applied = false;
    await _db.transaction(_user(uid), (cur) {
      applied = false;
      if (cur == null) return null; // 서버 값으로 다시 불린다
      final p = Profile.fromJson(cur);
      final w = p.byId(ownedId);
      if (w == null || w.level != fromLevel || p.gold < cost) return txAbort;
      applied = true;
      final m = {...(cur as Map<Object?, Object?>)};
      final weapons = {...(m['weapons']! as Map<Object?, Object?>)};
      weapons[ownedId] = {
        ...(weapons[ownedId]! as Map<Object?, Object?>),
        'level': fromLevel + (success ? 1 : 0),
      };
      m['weapons'] = weapons;
      m['gold'] = p.gold - cost;
      return m;
    });
    return applied;
  }

  /// 장착. [primary]면 주무기 칸, 아니면 보조 칸에 [ownedId].
  Future<void> equip(String uid, String ownedId, {required bool primary}) =>
      _db.update('${_user(uid)}/loadout', {
        primary ? 'primary' : 'secondary': ownedId,
      });
}
