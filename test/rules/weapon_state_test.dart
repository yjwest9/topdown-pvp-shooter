import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/weapon_state.dart';

void main() {
  test('starts with a full magazine', () {
    expect(WeaponState(rifleStandard).ammo, 30);
  });

  test('firing uses one round and waits the fire interval', () {
    final w = WeaponState(sniperBolt); // 1.3s
    expect(w.tryFire(), isTrue);
    expect(w.ammo, 4);
    w.tick(1.25);
    expect(w.tryFire(), isFalse);
    expect(w.ammo, 4);
    w.tick(0.125);
    expect(w.tryFire(), isTrue);
    expect(w.ammo, 3);
  });

  test('empty magazine reloads automatically after reload time', () {
    final w = WeaponState(shotgunDouble); // 탄창 2, 재장전 2.6s
    w.tryFire();
    w.tick(0.25);
    w.tryFire();
    expect(w.ammo, 0);
    w.tick(0.5);
    expect(w.reloading, isTrue);
    expect(w.tryFire(), isFalse);
    w.tick(2.0);
    expect(w.ammo, 0, reason: '2.5s < 2.6s');
    w.tick(0.125);
    expect(w.reloading, isFalse);
    expect(w.ammo, 2);
  });

  test('reload progress goes 0 -> 1', () {
    final w =
        WeaponState(pistol) // 재장전 1.2s
          ..ammo = 3
          ..reload();
    expect(w.reloadProgress, 0);
    w.tick(0.6);
    expect(w.reloadProgress, closeTo(0.5, 1e-9));
  });

  test('manual reload fills the magazine; ignored when full', () {
    final w = WeaponState(rifleStandard)..reload();
    expect(w.reloading, isFalse);

    w.tryFire();
    w.reload();
    expect(w.reloading, isTrue);
    w.tick(1.875);
    expect(w.ammo, 30);
  });

  test('cancelReload keeps ammo; an empty weapon starts again on tick', () {
    final w = WeaponState(rifleStandard)
      ..ammo = 10
      ..reload();
    w.tick(1);
    w.cancelReload();
    expect(w.reloading, isFalse);
    expect(w.ammo, 10);

    w
      ..ammo = 0
      ..cancelReload();
    w.tick(0.125);
    expect(w.reloading, isTrue);
  });
}
