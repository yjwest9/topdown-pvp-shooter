import 'dart:math';

import 'balance.dart';

/// 한 병사의 자세 상태 (decisions 3장). 위치·충돌은 모르고, 판정 결과만 받는다.
class StanceState {
  /// 남은 공중 시간. 0보다 크면 공중.
  double airTime = 0;
  double jumpCooldownLeft = 0;
  bool crouching = false;
  bool running = false;

  /// 낮은 상자 위에 서 있음.
  bool onCrate = false;

  bool get airborne => airTime > 0;

  /// 공중이거나 상자 위면 낮은 상자에 막히지 않는다(높은 벽은 항상 막힘).
  bool get ignoresLowCrates => airborne || onCrate;

  /// [speed]는 실제 이동 속도(px/s). 서기/걷기 구분에만 쓴다.
  Stance stance(double speed) {
    if (airborne) return Stance.jumping;
    if (running) return Stance.running;
    if (crouching) return Stance.crouching;
    return speed > movingSpeedThreshold ? Stance.walking : Stance.standing;
  }

  /// 서기·걷기는 둘 다 1.0이라 속도와 무관하다.
  double get moveSpeedMultiplier => stanceStats[stance(0)]!.speed;

  bool jump() {
    if (airborne || jumpCooldownLeft > 0) return false;
    airTime = jumpDuration;
    jumpCooldownLeft = jumpCooldown;
    crouching = false;
    return true;
  }

  /// 달리는 중에도 바로 앉는다(달리기는 꺼지고 이동은 앉은 속도로 계속).
  bool toggleCrouch() {
    if (airborne) return false;
    crouching = !crouching;
    if (crouching) running = false;
    return true;
  }

  /// 지난 프레임에 달리기 조건(달리기 입력 + 이동 0.3 이상)이었는지.
  bool _runHeld = false;

  /// 달리기를 새로 시작하는 순간에만 앉기가 풀린다.
  /// 앉은 뒤 달리기 입력을 계속 누르고 있어도 다시 일어나지 않는다.
  /// [firing]이면 걷기로(달리기 입력은 유지되어 사격이 끝나면 다시 달림).
  void updateRunning({
    required bool wantsRun,
    required double inputMagnitude,
    bool firing = false,
  }) {
    final held = wantsRun && inputMagnitude >= runMinInput;
    if (held && !_runHeld) crouching = false;
    _runHeld = held;
    running = held && !crouching && !firing;
  }

  /// 이동이 끝난 뒤 매 프레임 호출.
  /// [centerInLowCrate]: 몸 중심이 낮은 상자 안. [overlapsLowCrate]: 몸이 낮은 상자에 닿음.
  void tick(
    double dt, {
    required bool centerInLowCrate,
    required bool overlapsLowCrate,
  }) {
    jumpCooldownLeft = max(0, jumpCooldownLeft - dt);
    if (airborne) {
      airTime -= dt;
      if (airTime > 0) return;
      airTime = 0;
      if (centerInLowCrate) {
        onCrate = true;
      } else if (overlapsLowCrate) {
        airTime = edgeSlideExtension;
      }
    } else if (onCrate && !centerInLowCrate) {
      onCrate = false;
      if (overlapsLowCrate) airTime = edgeSlideExtension;
    }
  }
}
