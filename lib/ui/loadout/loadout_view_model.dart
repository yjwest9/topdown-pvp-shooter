import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/profile.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../rules/balance.dart';
import '../../rules/upgrade.dart';
import '../../rules/weapon_merge.dart';

/// 장착한 무기(로드아웃)와 강화 단계. 프로필이 없거나 옛 데이터면 기본 무기 +0.
({
  WeaponStats primary,
  Grade primaryGrade,
  int primaryLevel,
  WeaponStats secondary,
  Grade secondaryGrade,
  int secondaryLevel,
})
equippedWeapons(Profile? p) {
  final pw = p?.byId(p.primaryId), sw = p?.byId(p.secondaryId);
  final primary = weaponById(pw?.weaponId ?? '');
  final secondary = weaponById(sw?.weaponId ?? '');
  return (
    primary: primary ?? startingPrimary,
    primaryGrade: gradeFromString(pw?.grade),
    primaryLevel: primary == null ? 0 : pw!.level,
    secondary: secondary ?? startingSecondary,
    secondaryGrade: gradeFromString(sw?.grade),
    secondaryLevel: secondary == null ? 0 : sw!.level,
  );
}

class LoadoutState {
  const LoadoutState({
    required this.profile,
    required this.family,
    required this.selected,
    this.busy = false,
    this.upgradeResult,
    this.upgradeSeq = 0,
    this.mergeSeq = 0,
  });

  final Profile profile;

  /// 위쪽 탭(라이플 / 저격 / 샷건 / 보조).
  final WeaponFamily family;

  /// 오른쪽에 보이는 무기.
  final WeaponStats selected;
  final bool busy;

  /// 마지막 강화 결과(연출용). [upgradeSeq]가 바뀔 때마다 한 번 보여 준다.
  final UpgradeOutcome? upgradeResult;
  final int upgradeSeq;

  /// 합성에 성공할 때마다 +1(화면이 결과를 한 번 알리는 용도).
  final int mergeSeq;

  List<WeaponStats> get list => [
    for (final w in weapons)
      if (w.family == family) w,
  ];

  bool owns(WeaponStats w) => profile.owned(w.id) != null;

  /// 보유 무기의 강화 단계(없으면 0).
  int levelOf(WeaponStats w) => profile.owned(w.id)?.level ?? 0;

  /// 보유 무기의 등급(없으면 E).
  Grade gradeOf(WeaponStats w) => gradeFromString(profile.owned(w.id)?.grade);

  OwnedWeapon? get selectedOwned => profile.owned(selected.id);

  /// 합성 판정용 값. 모르는 무기면 null.
  MergeWeapon? mergeItem(OwnedWeapon? o) {
    final w = o == null ? null : weaponById(o.weaponId);
    if (o == null || w == null) return null;
    return (
      id: o.id,
      family: w.family,
      grade: gradeFromString(o.grade),
      level: o.level,
      equipped: o.id == profile.primaryId || o.id == profile.secondaryId,
    );
  }

  /// 고른 무기를 기준으로 합성할 수 있는 무기인가(E+5, 라이플·저격·샷건).
  bool get canMerge {
    final base = mergeItem(selectedOwned);
    return base != null && isMergeable(base);
  }

  /// 재료 후보: 기준과 같은 계열의 다른 E+5 개체. 장착 중이면 [equipped](고를 수 없음).
  List<({WeaponStats weapon, OwnedWeapon owned, bool equipped})>
  get mergeMaterials {
    final base = mergeItem(selectedOwned);
    if (base == null || !isMergeable(base)) return const [];
    return [
      for (final o in profile.weapons)
        if (mergeItem(o) case final m?
            when m.id != base.id && isMergeable(m) && m.family == base.family)
          (weapon: weaponById(o.weaponId)!, owned: o, equipped: m.equipped),
    ];
  }

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
    UpgradeOutcome? upgradeResult,
    int? upgradeSeq,
    int? mergeSeq,
  }) => LoadoutState(
    profile: profile ?? this.profile,
    family: family ?? this.family,
    selected: selected ?? this.selected,
    busy: busy ?? this.busy,
    upgradeResult: upgradeResult ?? this.upgradeResult,
    upgradeSeq: upgradeSeq ?? this.upgradeSeq,
    mergeSeq: mergeSeq ?? this.mergeSeq,
  );
}

/// 강화 확률을 굴리는 0~1 난수. 테스트는 정해진 값으로 바꾼다.
final upgradeRollProvider = Provider<double Function()>(
  (ref) => Random().nextDouble,
);

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

  /// 고른 보유 무기를 한 번 강화한다. 확률은 여기서 한 번만 굴리고 저장소에 결과를 넘긴다.
  /// 골드 부족·최대 단계면 저장하지 않고 그 결과만. 저장 중 무기 단계나 골드가 바뀌어
  /// 있었으면(다른 기기 등) 아무것도 안 바꾸고 null.
  Future<UpgradeOutcome?> upgrade() async {
    final owned = state.profile.owned(state.selected.id);
    if (owned == null || state.busy) return null;
    final level = owned.level;
    final outcome = tryUpgrade(
      level: level,
      gold: state.profile.gold,
      roll: ref.read(upgradeRollProvider)(),
    );
    if (outcome == UpgradeOutcome.notEnoughGold ||
        outcome == UpgradeOutcome.maxLevel) {
      return outcome;
    }
    state = state.copyWith(busy: true);
    try {
      final applied = await _repo.upgrade(
        await _auth.signIn(),
        owned.id,
        fromLevel: level,
        cost: upgradeCost(level),
        success: outcome == UpgradeOutcome.success,
      );
      if (!applied) return null;
      state = state.copyWith(
        upgradeResult: outcome,
        upgradeSeq: state.upgradeSeq + 1,
      );
      return outcome;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  /// 고른 무기(기준)에 [materialId] 무기를 합성한다(decisions 7장). 조건이 안 맞거나 저장 중
  /// 바뀌어 있었으면(다른 기기 등) 아무것도 안 바꾸고 false.
  Future<bool> merge(String materialId) async {
    final p = state.profile;
    final base = state.mergeItem(state.selectedOwned);
    final material = state.mergeItem(p.byId(materialId));
    if (base == null || material == null || state.busy) return false;
    if (checkMerge(base: base, material: material, gold: p.gold) !=
        MergeCheck.ok) {
      return false;
    }
    state = state.copyWith(busy: true);
    try {
      final applied = await _repo.mergeWeapons(
        await _auth.signIn(),
        base.id,
        materialId,
        cost: mergeCost,
        level: maxUpgradeLevel,
        sameFamily: (a, b) {
          final fa = weaponById(a)?.family;
          return fa != null && fa == weaponById(b)?.family;
        },
      );
      if (applied) state = state.copyWith(mergeSeq: state.mergeSeq + 1);
      return applied;
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
