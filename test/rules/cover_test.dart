import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/balance.dart';
import 'package:topsoldier/rules/cover.dart';
import 'package:topsoldier/rules/movement.dart';

/// 낮은 상자 하나를 사이에 두고 viewer(왼쪽) → target(오른쪽).
/// 상자: x 200~250. target은 상자 오른쪽 면에서 30px (50px 이내).
const crate = (left: 200.0, top: 100.0, right: 250.0, bottom: 150.0);
const wall = (left: 200.0, top: 100.0, right: 230.0, bottom: 150.0);
const viewerPos = (x: 0.0, y: 125.0);
const targetPos = (x: 280.0, y: 125.0);

CoverBody body(
  Vec pos, {
  bool crouching = false,
  bool airborne = false,
  bool onCrate = false,
}) => (pos: pos, crouching: crouching, airborne: airborne, onCrate: onCrate);

final viewer = body(viewerPos);
final standing = body(targetPos);
final crouchedBehind = body(targetPos, crouching: true);
final jumping = body(targetPos, airborne: true);
final onTop = body((x: 225.0, y: 125.0), onCrate: true);

void main() {
  // decisions 4장 표: 행 = 엄폐물, 열 = target 상태.
  group('high wall blocks sight and bullets in every case', () {
    for (final (name, t) in [
      ('standing', standing),
      ('crouched right behind', crouchedBehind),
      ('jumping', jumping),
      ('on a crate', onTop),
    ]) {
      test(name, () {
        expect(lineBlockedByHighWall(viewer.pos, t.pos, [wall]), isTrue);
      });
    }
  });

  group('low crate', () {
    test('standing: visible and hittable', () {
      expect(hiddenBehindLowCover(standing, viewer, [crate]), isFalse);
      expect(
        bulletBlockedByLowCover(
          target: standing,
          shooter: viewer,
          lowCrates: [crate],
        ),
        isFalse,
      );
    });
    test('crouched within 50px behind: hidden and not hittable', () {
      expect(hiddenBehindLowCover(crouchedBehind, viewer, [crate]), isTrue);
      expect(
        bulletBlockedByLowCover(
          target: crouchedBehind,
          shooter: viewer,
          lowCrates: [crate],
        ),
        isTrue,
      );
    });
    test('jumping: visible and hittable', () {
      // 점프 중엔 앉을 수 없지만, 앉음 플래그가 남아 있어도 공중이면 보인다.
      final t = body(targetPos, crouching: true, airborne: true);
      expect(hiddenBehindLowCover(t, viewer, [crate]), isFalse);
      expect(
        bulletBlockedByLowCover(target: t, shooter: viewer, lowCrates: [crate]),
        isFalse,
      );
    });
    test('on a crate: visible and hittable (even crouched)', () {
      final t = body((x: 225.0, y: 125.0), crouching: true, onCrate: true);
      expect(hiddenBehindLowCover(t, viewer, [crate]), isFalse);
      expect(
        bulletBlockedByLowCover(target: t, shooter: viewer, lowCrates: [crate]),
        isFalse,
      );
    });
  });

  group('viewer / shooter on a crate sees over low cover', () {
    final high = body((x: 0.0, y: 125.0), onCrate: true);
    test('sees a crouched target', () {
      expect(hiddenBehindLowCover(crouchedBehind, high, [crate]), isFalse);
    });
    test('bullet is not blocked', () {
      expect(
        bulletBlockedByLowCover(
          target: crouchedBehind,
          shooter: high,
          lowCrates: [crate],
        ),
        isFalse,
      );
    });
  });

  group('edge cases', () {
    test('crouched farther than 50px from the crate is visible', () {
      final t = body((x: 320.0, y: 125.0), crouching: true); // 70px
      expect(hiddenBehindLowCover(t, viewer, [crate]), isFalse);
    });
    test('crate not on the line of sight does not hide', () {
      // target은 상자 30px 옆에 앉았지만 viewer가 바로 아래에서 봄.
      final v = body((x: 280.0, y: 500.0));
      expect(hiddenBehindLowCover(crouchedBehind, v, [crate]), isFalse);
    });
    test('crate behind the target (viewer side clear) does not hide', () {
      // viewer가 오른쪽에서 봄: 상자는 target 뒤쪽이라 선 위에 없다.
      final v = body((x: 500.0, y: 125.0));
      expect(hiddenBehindLowCover(crouchedBehind, v, [crate]), isFalse);
    });
  });

  group('hitRadius', () {
    test('crouching 16 x 0.7, otherwise 16', () {
      expect(hitRadius(Stance.crouching), closeTo(11.2, 1e-9));
      expect(hitRadius(Stance.standing), 16);
      expect(hitRadius(Stance.jumping), 16);
    });
  });

  group('segmentHitsBox', () {
    test('crossing, missing, parallel', () {
      expect(segmentHitsBox((x: 0, y: 125), (x: 300, y: 125), crate), isTrue);
      expect(segmentHitsBox((x: 0, y: 50), (x: 300, y: 50), crate), isFalse);
      expect(segmentHitsBox((x: 0, y: 125), (x: 150, y: 125), crate), isFalse);
      expect(segmentHitsBox((x: 225, y: 0), (x: 225, y: 300), crate), isTrue);
    });
  });
}
