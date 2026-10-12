import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/profile.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../rules/balance.dart';

/// 장착한 무기(로드아웃). 프로필이 없거나 옛 데이터면 기본 무기.
({WeaponStats primary, WeaponStats secondary}) equippedWeapons(Profile? p) => (
  primary: weaponById(p?.byId(p.primaryId)?.weaponId ?? '') ?? startingPrimary,
  secondary:
      weaponById(p?.byId(p.secondaryId)?.weaponId ?? '') ?? startingSecondary,
);

class LoadoutState {
  const LoadoutState({
    required this.profile,
    required this.family,
    required this.selected,
    this.busy = false,
  });

  final Profile profile;

  /// 위쪽 탭(라이플 / 저격 / 샷건 / 보조).
  final WeaponFamily family;

  /// 오른쪽에 보이는 무기.
  final WeaponStats selected;
  final bool busy;

  List<WeaponStats> get list => [
    for (final w in weapons)
      if (w.family == family) w,
  ];

  bool owns(WeaponStats w) => profile.owned(w.id) != null;

  bool isEquipped(WeaponStats w) {
    final e = equippedWeapons(profile);
    return w == e.primary || w == e.secondary;
  }

  bool get canAfford => profile.gold >= weaponPrice;

  LoadoutState copyWith({
    Profile? profile,
    WeaponFamily? family,
    WeaponStats? selected,
    bool? busy,
  }) => LoadoutState(
    profile: profile ?? this.profile,
    family: family ?? this.family,
    selected: selected ?? this.selected,
    busy: busy ?? this.busy,
  );
}

final loadoutProvider =
    NotifierProvider.autoDispose<LoadoutViewModel, LoadoutState>(
      LoadoutViewModel.new,
    );

class LoadoutViewModel extends Notifier<LoadoutState> {
  AuthRepository get _auth => ref.read(authRepositoryProvider);
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  @override
  LoadoutState build() {
    final profile =
        ref.watch(profileProvider).value ?? Profile(nickname: _auth.nickname);
    final prev = stateOrNull;
    if (prev != null) return prev.copyWith(profile: profile);
    final primary = equippedWeapons(profile).primary;
    return LoadoutState(
      profile: profile,
      family: primary.family,
      selected: primary,
    );
  }

  /// 탭: 그 계열의 첫 무기를 보여 준다.
  void showFamily(WeaponFamily f) => state = state.copyWith(
    family: f,
    selected: weapons.firstWhere((w) => w.family == f),
  );

  void select(WeaponStats w) => state = state.copyWith(selected: w);

  /// 골드가 모자라거나 이미 있으면 false.
  Future<bool> buy() async {
    final w = state.selected;
    if (state.owns(w) || !state.canAfford || state.busy) return false;
    state = state.copyWith(busy: true);
    try {
      return await _repo.buy(await _auth.signIn(), w.id, weaponPrice);
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  /// 권총은 보조 칸, 나머지는 주무기 칸.
  Future<void> equip() async {
    final owned = state.profile.owned(state.selected.id);
    if (owned == null) return;
    await _repo.equip(
      await _auth.signIn(),
      owned.id,
      primary: state.selected.family != WeaponFamily.pistol,
    );
  }
}
