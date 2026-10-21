import 'balance.dart';

/// 합성 판정에 쓰는 보유 무기 한 개체(decisions 7장). [equipped]는 로드아웃에 장착 중.
typedef MergeWeapon = ({
  String id,
  WeaponFamily family,
  Grade grade,
  int level,
  bool equipped,
});

/// [checkMerge] 결과. [ok]만 합성할 수 있다.
enum MergeCheck {
  ok,
  notMergeable,
  differentFamily,
  sameWeapon,
  materialEquipped,
  notEnoughGold,
}

/// 합성 대상: 라이플·저격·샷건의 E+5. 권총은 계열에 1종뿐이라 제외.
bool isMergeable(MergeWeapon w) =>
    w.family != WeaponFamily.pistol &&
    w.grade == Grade.e &&
    w.level == maxUpgradeLevel;

/// [base](먼저 고른 무기)와 [material]을 [gold]로 합성할 수 있는지. 기준은 장착 중이어도 되고
/// 재료는 안 된다.
MergeCheck checkMerge({
  required MergeWeapon base,
  required MergeWeapon material,
  required int gold,
}) {
  if (base.id == material.id) return MergeCheck.sameWeapon;
  if (!isMergeable(base) || !isMergeable(material)) {
    return MergeCheck.notMergeable;
  }
  if (base.family != material.family) return MergeCheck.differentFamily;
  if (material.equipped) return MergeCheck.materialEquipped;
  if (gold < mergeCost) return MergeCheck.notEnoughGold;
  return MergeCheck.ok;
}

/// 기준 무기가 합성 뒤에 되는 등급·단계(재료는 사라진다).
({Grade grade, int level}) mergedResult() => (grade: Grade.d, level: 0);
