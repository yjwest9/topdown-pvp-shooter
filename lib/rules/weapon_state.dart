import 'dart:math';

import 'balance.dart';

/// 무기 한 자루의 탄약·연사 대기·재장전 (decisions 6장).
class WeaponState {
  WeaponState(this.weapon) : ammo = weapon.magazine;

  final WeaponStats weapon;
  int ammo;
  double cooldown = 0;
  double reloadLeft = 0;

  bool get reloading => reloadLeft > 0;

  /// 재장전 진행 0~1. 재장전 중이 아니면 0.
  double get reloadProgress =>
      reloading ? 1 - reloadLeft / weapon.reloadTime : 0;

  /// 쏠 수 있으면 탄을 하나 쓰고 true.
  bool tryFire() {
    if (ammo <= 0 || cooldown > 0 || reloading) return false;
    ammo--;
    cooldown = weapon.fireInterval;
    return true;
  }

  /// 탄이 가득이거나 이미 재장전 중이면 무시.
  void reload() {
    if (reloading || ammo == weapon.magazine) return;
    reloadLeft = weapon.reloadTime;
  }

  /// 부활 시: 탄창 가득, 재장전·연사 대기 없음.
  void refill() {
    ammo = weapon.magazine;
    reloadLeft = 0;
    cooldown = 0;
  }

  /// 무기 교체 시. 탄은 그대로.
  void cancelReload() => reloadLeft = 0;

  /// 탄이 0이면 이 tick부터 자동 재장전(쏜 직후 tick이면 쏜 순간부터 센 것과 같다).
  void tick(double dt) {
    cooldown = max(0, cooldown - dt);
    if (ammo == 0 && !reloading) reloadLeft = weapon.reloadTime;
    if (!reloading) return;
    reloadLeft -= dt;
    if (reloadLeft <= 0) {
      reloadLeft = 0;
      ammo = weapon.magazine;
    }
  }
}
