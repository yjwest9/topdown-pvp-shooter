import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/profile.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../rules/balance.dart';
import '../../rules/upgrade.dart';
import '../loadout/loadout_view_model.dart';

class CharacterState {
  const CharacterState({
    required this.profile,
    required this.selected,
    this.busy = false,
    this.upgradeResult,
    this.upgradeSeq = 0,
  });

  final Profile profile;

  /// 오른쪽에 보이는 캐릭터(+0 기준 표).
  final CharacterStats selected;
  final bool busy;

  /// 마지막 강화 결과(연출용). [upgradeSeq]가 바뀔 때마다 한 번 보여 준다.
  final UpgradeOutcome? upgradeResult;
  final int upgradeSeq;

  /// 기본 병사는 무료라 늘 보유(지급 전이어도).
  bool owns(CharacterStats c) =>
      c == basicSoldier || profile.characters.containsKey(c.id);

  int levelOf(CharacterStats c) => profile.characters[c.id] ?? 0;

  bool isEquipped(CharacterStats c) =>
      c.id == profile.equippedCharacter ||
      (c == basicSoldier &&
          !characters.any((x) => x.id == profile.equippedCharacter));

  bool get canAfford => profile.diamond >= characterPrice;

  CharacterState copyWith({
    Profile? profile,
    CharacterStats? selected,
    bool? busy,
    UpgradeOutcome? upgradeResult,
    int? upgradeSeq,
  }) => CharacterState(
    profile: profile ?? this.profile,
    selected: selected ?? this.selected,
    busy: busy ?? this.busy,
    upgradeResult: upgradeResult ?? this.upgradeResult,
    upgradeSeq: upgradeSeq ?? this.upgradeSeq,
  );
}

final characterProvider =
    NotifierProvider.autoDispose<CharacterViewModel, CharacterState>(
      CharacterViewModel.new,
    );

/// 캐릭터 화면(decisions 8장): 구매(다이아), 장착, 강화(골드, 무기와 같은 비용·확률).
class CharacterViewModel extends Notifier<CharacterState> {
  AuthRepository get _auth => ref.read(authRepositoryProvider);
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  @override
  CharacterState build() {
    final profile =
        ref.watch(profileProvider).value ?? Profile(nickname: _auth.nickname);
    final prev = stateOrNull;
    if (prev != null) return prev.copyWith(profile: profile);
    final s = CharacterState(profile: profile, selected: basicSoldier);
    return s.copyWith(
      selected: characters.firstWhere(s.isEquipped, orElse: () => basicSoldier),
    );
  }

  void select(CharacterStats c) => state = state.copyWith(selected: c);

  /// 다이아가 모자라거나 이미 있으면 false.
  Future<bool> buy() async {
    final c = state.selected;
    if (state.owns(c) || !state.canAfford || state.busy) return false;
    state = state.copyWith(busy: true);
    try {
      return await _repo.buyCharacter(
        await _auth.signIn(),
        c.id,
        characterPrice,
      );
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> equip() async {
    final c = state.selected;
    if (!state.owns(c)) return;
    await _repo.equipCharacter(await _auth.signIn(), c.id);
  }

  /// 무기 강화와 같은 흐름: 확률은 여기서 한 번만 굴리고 저장소에 결과를 넘긴다.
  /// 골드 부족·최대 단계면 저장하지 않고 그 결과만. 저장 중 바뀌어 있었으면 null.
  Future<UpgradeOutcome?> upgrade() async {
    final c = state.selected;
    if (!state.owns(c) || state.busy) return null;
    final level = state.levelOf(c);
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
      final applied = await _repo.upgradeCharacter(
        await _auth.signIn(),
        c.id,
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
}
