import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/stance.dart';

void main() {
  group('stance from state', () {
    test('standing / walking by speed (30px/s)', () {
      final s = StanceState();
      expect(s.stance(0), Stance.standing);
      expect(s.stance(30), Stance.standing);
      expect(s.stance(31), Stance.walking);
    });
    test('jumping > running > crouching', () {
      final s = StanceState()..crouching = true;
      expect(s.stance(100), Stance.crouching);
      s.updateRunning(wantsRun: true, inputMagnitude: 1);
      expect(s.stance(100), Stance.running);
      s.jump();
      expect(s.stance(100), Stance.jumping);
    });
  });

  group('move speed multiplier', () {
    test('standing 1.0, running 1.5, crouching 0.45, jumping 1.2', () {
      expect(StanceState().moveSpeedMultiplier, 1.0);
      expect(
        (StanceState()..updateRunning(wantsRun: true, inputMagnitude: 1))
            .moveSpeedMultiplier,
        1.5,
      );
      expect((StanceState()..toggleCrouch()).moveSpeedMultiplier, 0.45);
      expect((StanceState()..jump()).moveSpeedMultiplier, 1.2);
    });
  });

  group('running', () {
    test('needs input >= 0.3', () {
      final s = StanceState()
        ..updateRunning(wantsRun: true, inputMagnitude: 0.29);
      expect(s.running, isFalse);
      s.updateRunning(wantsRun: true, inputMagnitude: 0.3);
      expect(s.running, isTrue);
    });
    test('starting to run cancels crouch', () {
      final s = StanceState()..toggleCrouch();
      s.updateRunning(wantsRun: true, inputMagnitude: 1);
      expect(s.crouching, isFalse);
      expect(s.running, isTrue);
    });
    test('crouching while running: crouch now, stop running', () {
      final s = StanceState()..updateRunning(wantsRun: true, inputMagnitude: 1);
      expect(s.toggleCrouch(), isTrue);
      expect(s.crouching, isTrue);
      expect(s.running, isFalse);
      expect(s.moveSpeedMultiplier, 0.45);
    });
    test('still holding run after crouching does not stand up', () {
      final s = StanceState()
        ..updateRunning(wantsRun: true, inputMagnitude: 1)
        ..toggleCrouch();
      for (var i = 0; i < 10; i++) {
        s.updateRunning(wantsRun: true, inputMagnitude: 1);
      }
      expect(s.crouching, isTrue);
      expect(s.running, isFalse);
    });
    test('run again (release and press) stands up and runs', () {
      final s = StanceState()
        ..updateRunning(wantsRun: true, inputMagnitude: 1)
        ..toggleCrouch()
        ..updateRunning(wantsRun: false, inputMagnitude: 1)
        ..updateRunning(wantsRun: true, inputMagnitude: 1);
      expect(s.crouching, isFalse);
      expect(s.running, isTrue);
    });
    test('stopping and moving again while holding run also restarts run', () {
      // 조이스틱을 원 밖에 둔 채 손을 뗐다 다시 끄는 경우: 입력 0 → 1
      final s = StanceState()
        ..updateRunning(wantsRun: true, inputMagnitude: 1)
        ..toggleCrouch()
        ..updateRunning(wantsRun: true, inputMagnitude: 0)
        ..updateRunning(wantsRun: true, inputMagnitude: 1);
      expect(s.running, isTrue);
      expect(s.crouching, isFalse);
    });
  });

  group('running while firing', () {
    test('firing stops running, run resumes when firing stops', () {
      final s = StanceState()
        ..updateRunning(wantsRun: true, inputMagnitude: 1, firing: true);
      expect(s.running, isFalse);
      s.updateRunning(wantsRun: true, inputMagnitude: 1);
      expect(s.running, isTrue);
    });
  });

  group('crouch', () {
    test('toggles', () {
      final s = StanceState();
      expect(s.toggleCrouch(), isTrue);
      expect(s.crouching, isTrue);
      s.toggleCrouch();
      expect(s.crouching, isFalse);
    });
    test('cannot crouch in the air', () {
      final s = StanceState()..jump();
      expect(s.toggleCrouch(), isFalse);
      expect(s.crouching, isFalse);
    });
    test('jump releases crouch', () {
      final s = StanceState()
        ..toggleCrouch()
        ..jump();
      expect(s.crouching, isFalse);
    });
    test('can crouch on a crate', () {
      final s = StanceState()..onCrate = true;
      expect(s.toggleCrouch(), isTrue);
    });
  });

  group('jump', () {
    void land(StanceState s) =>
        s.tick(jumpDuration, centerInLowCrate: false, overlapsLowCrate: false);

    test('lasts 0.5s', () {
      final s = StanceState()..jump();
      s.tick(0.375, centerInLowCrate: false, overlapsLowCrate: false);
      expect(s.airborne, isTrue);
      s.tick(0.125, centerInLowCrate: false, overlapsLowCrate: false);
      expect(s.airborne, isFalse);
    });
    test('cooldown 0.75s from jump start, landing included', () {
      final s = StanceState()..jump();
      land(s);
      expect(s.jump(), isFalse, reason: 'landed at 0.5s, still cooling down');
      s.tick(0.125, centerInLowCrate: false, overlapsLowCrate: false);
      expect(s.jump(), isFalse);
      s.tick(0.125, centerInLowCrate: false, overlapsLowCrate: false);
      expect(s.jump(), isTrue);
    });
    test('cannot jump in the air', () {
      final s = StanceState()..jump();
      expect(s.jump(), isFalse);
    });
    test('ignores low crates only while airborne or on a crate', () {
      final s = StanceState();
      expect(s.ignoresLowCrates, isFalse);
      s.jump();
      expect(s.ignoresLowCrates, isTrue);
      land(s);
      expect(s.ignoresLowCrates, isFalse);
      s.onCrate = true;
      expect(s.ignoresLowCrates, isTrue);
    });
  });

  group('crate', () {
    test('landing with center inside a low crate -> onCrate', () {
      final s = StanceState()..jump();
      s.tick(jumpDuration, centerInLowCrate: true, overlapsLowCrate: true);
      expect(s.onCrate, isTrue);
      expect(s.airborne, isFalse);
    });
    test('landing on the edge -> stays airborne 0.03s to slide off', () {
      final s = StanceState()..jump();
      s.tick(jumpDuration, centerInLowCrate: false, overlapsLowCrate: true);
      expect(s.onCrate, isFalse);
      expect(s.airborne, isTrue);
      expect(s.airTime, closeTo(edgeSlideExtension, 1e-9));
    });
    test('walking off the crate -> onCrate false', () {
      final s = StanceState()..onCrate = true;
      s.tick(0.016, centerInLowCrate: false, overlapsLowCrate: false);
      expect(s.onCrate, isFalse);
      expect(s.airborne, isFalse);
    });
    test('walking off but body still on the edge -> slides off', () {
      final s = StanceState()..onCrate = true;
      s.tick(0.016, centerInLowCrate: false, overlapsLowCrate: true);
      expect(s.onCrate, isFalse);
      expect(s.airborne, isTrue);
    });
    test('staying on the crate keeps onCrate', () {
      final s = StanceState()..onCrate = true;
      s.tick(0.016, centerInLowCrate: true, overlapsLowCrate: true);
      expect(s.onCrate, isTrue);
    });
  });
}
