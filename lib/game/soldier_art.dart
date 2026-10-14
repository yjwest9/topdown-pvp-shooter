import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import '../rules/appearance.dart';

/// 위에서 본 병사(decisions 3장·8장). 홈 정면 그림과 같은 실루엣 택티컬 스타일:
/// 어두운 몸 + 캐릭터 색의 밝은 테두리, 헬멧·방탄조끼·배낭 같은 장비 윤곽, 밝은 총.
/// 몸 중심이 (0, 0), 오른쪽(+x)을 보고, 오른손(그립)은 +y 쪽. 판정 반지름 16px 원 안에 들어간다.
/// 캐릭터·포즈마다 한 번 그려 둔 그림을 다시 쓴다(매 프레임 경로를 만들지 않게).
class SoldierArt {
  SoldierArt._();

  static final _cache = <(String, Pose), Picture>{};

  static void draw(Canvas canvas, String characterId, Pose pose) =>
      canvas.drawPicture(
        _cache.putIfAbsent((
          characterId,
          pose,
        ), () => _record(characterLook(characterId), pose)),
      );

  static const _base = Color(0xFF15181C);
  static const _gun = Color(0xFF3A4048);
  static const _gunEdge = Color(0xFFB9C2CC);

  static Picture _record(CharacterLook look, Pose pose) {
    final rec = PictureRecorder();
    final canvas = Canvas(rec);
    final top = Color(look.top);
    final rim = Color.lerp(top, const Color(0xFFFFFFFF), 0.5)!;
    Color tone(double f) => Color.lerp(_base, top, f)!;
    final suit = look.tie;

    // 포즈: 총(시작, 끝, 굵기)과 두 손(오른손 = 그립, 왼손 = 총몸 앞), 두 팔꿈치.
    final (gunFrom, gunTo, gunW, rightHand, leftHand) = switch (pose) {
      Pose.machine => (
        const Offset(1, 4),
        const Offset(27, 4),
        3.4,
        const Offset(7, 6.5),
        const Offset(17, 3),
      ),
      Pose.silencer => (
        const Offset(0, 4),
        const Offset(33, 4),
        3.0,
        const Offset(6, 6.5),
        const Offset(19, 3),
      ),
      Pose.gun => (
        const Offset(15, 0),
        const Offset(23, 0),
        3.2,
        const Offset(15, 1.6),
        const Offset(15, -1.6),
      ),
      // 재장전: 총을 몸 쪽으로 기울이고 왼손은 탄창을 쥔다.
      Pose.reload => (
        const Offset(2, 7),
        const Offset(21, 13),
        3.4,
        const Offset(7, 9),
        const Offset(7, -3),
      ),
      Pose.stand => (
        Offset.zero,
        Offset.zero,
        0.0,
        const Offset(1, 12.5),
        const Offset(1, -12.5),
      ),
    };
    const shoulderR = Offset(-1, 10), shoulderL = Offset(-1, -10);
    final (elbowR, elbowL) = switch (pose) {
      Pose.machine => (const Offset(4, 10.5), const Offset(9, -6)),
      Pose.silencer => (const Offset(3.5, 10.5), const Offset(10, -6)),
      Pose.gun => (const Offset(7, 8), const Offset(7, -8)),
      Pose.reload => (const Offset(4, 11), const Offset(3, -8)),
      Pose.stand => (const Offset(0, 11.5), const Offset(0, -11.5)),
    };

    final torso = Path()
      ..addOval(
        Rect.fromCenter(
          center: const Offset(-1, 0),
          width: 13,
          height: suit ? 24 : 27,
        ),
      );
    final head = Path()
      ..addOval(
        Rect.fromCircle(
          center: const Offset(1, 0),
          radius: look.helmet ? 6.0 : 5.5,
        ),
      );
    // 팔: 어깨 → 팔꿈치 → 손(위팔이 조금 더 굵다).
    Path arm(Offset shoulder, Offset elbow, Offset hand) => Path.combine(
      PathOperation.union,
      _limb(shoulder, elbow, 4.6),
      _limb(elbow, hand, 3.8),
    );
    final arms = [
      arm(shoulderR, elbowR, rightHand),
      arm(shoulderL, elbowL, leftHand),
    ];
    final body = [
      if (look.backpack) _rr(-12, -8, -4, 8, 3),
      torso,
      ...arms,
      head,
      if (look.messyHair)
        for (final (x, y) in [(-2.2, -3.8), (-3.0, 0.0), (-2.2, 3.8)])
          Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: 2.6)),
      if (look.headset) ...[
        _rr(-1.5, -7.8, 2.5, -4.9, 1.5),
        _rr(-1.5, 4.9, 2.5, 7.8, 1.5),
      ],
    ].reduce((a, b) => Path.combine(PathOperation.union, a, b));

    // 밝은 테두리(바닥에서 잘 보이게) → 어두운 몸.
    canvas
      ..drawPath(
        body,
        Paint()
          ..color = rim
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(body, Paint()..color = _base);

    final seam = Paint()
      ..color = const Color(0x2EFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    void fill(Path p, Color c) => canvas
      ..drawPath(p, Paint()..color = c)
      ..drawPath(p, seam);

    canvas
      ..save()
      ..clipPath(body);
    if (look.backpack) fill(_rr(-12, -8, -4, 8, 3), tone(0.3));
    fill(torso, tone(suit ? 0.12 : 0.18));
    if (!suit) {
      // 방탄조끼 + 앞쪽 탄창 주머니
      fill(_rr(-6, -8, 5, 8, 3), tone(0.28));
      for (final y in [-6.0, -2.0, 2.0]) {
        fill(_rr(3, y, 6, y + 3.6, 1), tone(0.38));
      }
    }
    for (final a in arms) {
      fill(a, tone(suit ? 0.14 : 0.22));
    }
    canvas.restore();

    // 총(밝은 테두리 + 회색 몸통, 저격총은 조준경)
    if (pose != Pose.stand) {
      final gun = _limb(gunFrom, gunTo, gunW);
      canvas
        ..drawPath(
          gun,
          Paint()
            ..color = _gunEdge
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        )
        ..drawPath(gun, Paint()..color = _gun);
      if (pose == Pose.silencer) {
        canvas.drawPath(
          _rr(8, 1.6, 18, 6.4, 2),
          Paint()..color = const Color(0xFF23272D),
        );
      }
      if (pose == Pose.reload) {
        // 왼손의 탄창
        canvas.drawPath(_rr(4, -6, 10, -1.5, 1), Paint()..color = _gun);
      }
    }
    // 장갑
    for (final h in [rightHand, leftHand]) {
      canvas
        ..drawCircle(h, 2.9, Paint()..color = rim)
        ..drawCircle(h, 2.2, Paint()..color = tone(0.15));
    }

    // 머리: 헬멧(야간투시경 마운트) / 머리카락 + 헤드셋
    if (look.helmet) {
      fill(
        Path()
          ..addOval(Rect.fromCircle(center: const Offset(1, 0), radius: 6.0)),
        tone(0.32),
      );
      fill(_rr(4.8, -1.4, 7.6, 1.4, 1), tone(0.5));
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(1, 0), radius: 4.0),
        -pi * 0.85,
        pi * 0.6,
        false,
        Paint()
          ..color = const Color(0x40FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    } else {
      final hair = Color.lerp(_base, Color(look.hair), 0.55)!;
      fill(
        Path()
          ..addOval(Rect.fromCircle(center: const Offset(1, 0), radius: 5.5)),
        hair,
      );
      if (look.messyHair) {
        for (final (x, y) in [(-2.2, -3.8), (-3.0, 0.0), (-2.2, 3.8)]) {
          fill(
            Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: 2.6)),
            hair,
          );
        }
      }
      if (look.headset) {
        final cup = tone(0.45);
        fill(_rr(-1.5, -7.8, 2.5, -4.9, 1.5), cup);
        fill(_rr(-1.5, 4.9, 2.5, 7.8, 1.5), cup);
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(0.5, 0), radius: 5.8),
          pi / 2,
          pi,
          false,
          Paint()
            ..color = cup
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }
    return rec.endRecording();
  }

  /// [a]에서 [b]까지 폭 [w]의 둥근 막대(팔·총).
  static Path _limb(Offset a, Offset b, double w) {
    final d = b - a;
    final bar = Path()
      ..addRRect(
        RRect.fromLTRBR(
          -w / 2,
          -w / 2,
          d.distance + w / 2,
          w / 2,
          Radius.circular(w / 2),
        ),
      );
    final angle = atan2(d.dy, d.dx);
    final c = cos(angle), s = sin(angle);
    // 회전 후 이동(열 우선 4×4 행렬).
    return bar.transform(
      Float64List.fromList([
        c, s, 0, 0, //
        -s, c, 0, 0,
        0, 0, 1, 0,
        a.dx, a.dy, 0, 1,
      ]),
    );
  }

  static Path _rr(double l, double t, double r, double b, double radius) =>
      Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)));
}
