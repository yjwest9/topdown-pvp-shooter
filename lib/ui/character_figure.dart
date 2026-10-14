import 'dart:math';

import 'package:flutter/material.dart';

import '../game/weapon_art.dart';
import '../rules/appearance.dart';

/// 정면에서 본 서 있는 캐릭터(홈·캐릭터 화면, decisions 8장). 손에는 [weaponId] 무기.
/// 실루엣 택티컬 스타일: 실제 사람 비율의 어두운 실루엣 + 테두리 빛, 장비 윤곽 위주.
/// 벡터로 그려서 크게 키워도 선명하다. 가로:세로 = 100:160, [height]는 세로 길이.
class CharacterFigure extends StatelessWidget {
  const CharacterFigure(
    this.characterId, {
    super.key,
    required this.height,
    this.weaponId,
    this.dim = false,
  });

  final String characterId;
  final String? weaponId;
  final double height;

  /// 아직 안 산 캐릭터.
  final bool dim;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: dim ? 0.45 : 1,
    child: CustomPaint(
      size: Size(height * 100 / 160, height),
      painter: _FigurePainter(characterLook(characterId), weaponId),
    ),
  );
}

class _FigurePainter extends CustomPainter {
  _FigurePainter(this.look, this.weaponId);

  final CharacterLook look;
  final String? weaponId;

  /// 실루엣 바탕과 장비 톤(옷 색을 아주 어둡게 섞는다).
  static const _base = Color(0xFF14171B);
  static const _backRim = Color(0xCC7FB2E5);

  Color get _tint => Color(look.accent ?? look.top);
  Color get _keyRim => Color.lerp(Color(look.top), Colors.white, 0.45)!;
  Color _tone(double f) => Color.lerp(_base, Color(look.top), f)!;

  /// [a]에서 [b]까지 폭 [w]의 둥근 막대(팔·다리).
  static Path _limb(Offset a, Offset b, double w) {
    final d = b - a;
    final m = Matrix4.identity()
      ..translateByDouble(a.dx, a.dy, 0, 1)
      ..rotateZ(atan2(d.dy, d.dx));
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
    return bar.transform(m.storage);
  }

  static Path _rr(double l, double t, double r, double b, double radius) =>
      Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)));

  static Path _union(List<Path> parts) =>
      parts.reduce((a, b) => Path.combine(PathOperation.union, a, b));

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height / 160;
    canvas
      ..save()
      ..scale(s);

    final weapon = weaponId == null ? null : weaponLook(weaponId!);
    final pistol = weapon?.pistol ?? false;
    final suit = look.tie;

    // 자세. 라이플: 개머리판은 (그림 왼쪽) 어깨, 총구는 오른쪽 아래로 낮춤(로우 레디).
    // 권총: 두 손으로 몸 앞에서 아래로. 무기 없음: 팔을 내림.
    const gunAngle = 0.5;
    const dir = Offset(0.8776, 0.4794); // (cos 0.5, sin 0.5)
    const perp = Offset(-0.4794, 0.8776);
    const stock = Offset(37, 55);
    final gunLen = weapon == null
        ? 0.0
        : pistol
        ? 22.0
        : 64 * weapon.length / 124 + 6;
    final gunCenter = pistol
        ? const Offset(50, 91)
        : stock + dir * (gunLen / 2);
    const shoulderL = Offset(32, 46), shoulderR = Offset(68, 46);
    final (left, right, elbowL, elbowR) = weapon == null
        ? (
            const Offset(30, 95),
            const Offset(70, 95),
            const Offset(29, 70),
            const Offset(71, 70),
          )
        : pistol
        ? (
            const Offset(48, 84),
            const Offset(52.5, 85),
            const Offset(33, 67),
            const Offset(67, 67),
          )
        : (
            stock + dir * (gunLen * 0.33) + perp * 2,
            stock + dir * (gunLen * 0.62) + perp * 1.5,
            const Offset(31, 63),
            const Offset(73, 62),
          );

    // 팔(어깨 → 팔꿈치 → 손, 아래팔이 더 가늘다)
    final arms = [
      _union([_limb(shoulderL, elbowL, 10), _limb(elbowL, left, 8.5)]),
      _union([_limb(shoulderR, elbowR, 10), _limb(elbowR, right, 8.5)]),
    ];

    // ---------------------------------------------------------------- 실루엣
    final torso = Path()
      ..moveTo(40, 37)
      ..lineTo(60, 37)
      ..quadraticBezierTo(71, 38, 72.5, 47)
      ..lineTo(67, 83)
      ..lineTo(33, 83)
      ..lineTo(27.5, 47)
      ..quadraticBezierTo(29, 38, 40, 37)
      ..close();
    final parts = <Path>[
      if (look.backpack) _rr(29, 39, 71, 74, 6),
      torso,
      _rr(45.5, 30, 54.5, 40, 3), // 목
      Path()..addOval(
        Rect.fromCenter(center: const Offset(50, 24), width: 15, height: 19),
      ),
      _rr(33, 80, 67, 97, 4), // 골반
      _limb(const Offset(42, 94), const Offset(40, 122), 13), // 허벅지
      _limb(const Offset(58, 94), const Offset(60, 122), 13),
      _limb(const Offset(40, 122), const Offset(39, 145), 11), // 정강이
      _limb(const Offset(60, 122), const Offset(61, 145), 11),
      if (suit) ...[
        _rr(32, 143, 45, 151, 3),
        _rr(55, 143, 68, 151, 3),
      ] else ...[
        _rr(31, 142, 46, 153, 3), // 군화
        _rr(54, 142, 69, 153, 3),
      ],
      ...arms,
      if (look.helmet)
        Path()
          ..moveTo(39.5, 25)
          ..arcTo(const Rect.fromLTWH(39.5, 10, 21, 20), pi, pi, false)
          ..close()
      else ...[
        Path()
          ..moveTo(42, 22)
          ..arcTo(const Rect.fromLTWH(42, 13, 16, 15), pi, pi, false)
          ..close(),
        if (look.messyHair)
          for (final (x, y) in [(44.0, 16.0), (50.0, 13.5), (56.0, 16.0)])
            Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: 4)),
      ],
      if (look.headset) ...[
        _rr(39.5, 20, 43.5, 29, 2),
        _rr(56.5, 20, 60.5, 29, 2),
      ],
    ];
    final body = _union(parts);

    // 바닥 그림자 + 캐릭터 색이 살짝 비치는 바닥 빛
    canvas
      ..drawOval(
        const Rect.fromLTWH(20, 148, 60, 9),
        Paint()..color = const Color(0x66000000),
      )
      ..drawOval(
        const Rect.fromLTWH(26, 150, 48, 5),
        Paint()
          ..color = _tint.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

    // 테두리 빛: 오른쪽은 차가운 역광, 왼쪽 위는 캐릭터 색을 밝게. 그 위에 실루엣.
    canvas
      ..drawPath(body.shift(const Offset(1.4, 0.3)), Paint()..color = _backRim)
      ..drawPath(body.shift(const Offset(-1.3, -1.1)), Paint()..color = _keyRim)
      ..drawPath(body, Paint()..color = _base);

    // ---------------------------------------------------------------- 장비 디테일(실루엣 안)
    canvas
      ..save()
      ..clipPath(body);
    final seam = Paint()
      ..color = const Color(0x22FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    void fill(Path p, Color c) => canvas
      ..drawPath(p, Paint()..color = c)
      ..drawPath(p, seam);

    // 바지·상의 톤(옷 색이 아주 살짝 비친다)
    fill(_rr(33, 80, 67, 160, 0), _tone(0.10));
    fill(torso, _tone(suit ? 0.08 : 0.14));
    if (suit) {
      // 정장: 셔츠 V + 넥타이(포인트 색)
      fill(
        Path()..addPolygon(const [
          Offset(44.5, 37.5),
          Offset(55.5, 37.5),
          Offset(50, 58),
        ], true),
        const Color(0xFF3A3F47),
      );
      fill(_rr(49, 40, 51, 58, 1), _tint);
    } else {
      // 방탄조끼 + 탄창 주머니 3개 + 벨트
      fill(_rr(34, 45, 66, 77, 3), _tone(0.2));
      for (final x in [36.0, 46.0, 56.0]) {
        fill(_rr(x, 63, x + 8, 76, 1.5), _tone(0.28));
        canvas.drawLine(Offset(x, 66), Offset(x + 8, 66), seam);
      }
      fill(_rr(33, 80, 67, 84, 1), _tone(0.05));
      fill(_rr(47.5, 80.5, 52.5, 83.5, 1), _tone(0.35));
      // 무릎 보호대
      fill(_rr(34.5, 116, 45, 127, 3), _tone(0.25));
      fill(_rr(55, 116, 65.5, 127, 3), _tone(0.25));
    }
    if (look.backpack) {
      final strap = Paint()
        ..color = _tone(0.3)
        ..strokeWidth = 3;
      canvas
        ..drawLine(const Offset(37, 39), const Offset(38, 62), strap)
        ..drawLine(const Offset(63, 39), const Offset(62, 62), strap);
    }
    // 팔은 몸통 위에 따로 그려야 보인다(소매 톤 + 왼쪽 위 테두리 빛).
    for (final arm in arms) {
      canvas
        ..drawPath(
          arm.shift(const Offset(-0.7, -0.7)),
          Paint()..color = _keyRim.withValues(alpha: 0.7),
        )
        ..drawPath(arm, Paint()..color = _tone(suit ? 0.1 : 0.17))
        ..drawPath(arm, seam);
    }
    // 머리: 얼굴은 그림자, 위쪽만 살짝 밝게
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 24), width: 15, height: 19),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A2E34), Color(0xFF101215)],
        ).createShader(const Rect.fromLTWH(42, 14, 16, 20)),
    );
    if (look.helmet) {
      fill(
        Path()
          ..moveTo(39.5, 25)
          ..arcTo(const Rect.fromLTWH(39.5, 10, 21, 20), pi, pi, false)
          ..close(),
        _tone(0.22),
      );
      fill(_rr(47, 11.5, 53, 15.5, 1), _tone(0.4)); // 야간투시경 마운트
      fill(_rr(40.5, 20.5, 59.5, 24.5, 2), const Color(0xFF0C0D10)); // 고글
      _glint(canvas, _rr(43, 21.3, 49, 23.7, 1));
      _glint(canvas, _rr(51, 21.3, 57, 23.7, 1));
    } else {
      fill(
        Path()
          ..moveTo(42, 22)
          ..arcTo(const Rect.fromLTWH(42, 13, 16, 15), pi, pi, false)
          ..close(),
        Color.lerp(_base, Color(look.hair), 0.35)!,
      );
      if (look.sunglasses) {
        fill(_rr(43, 22, 57, 25, 1.5), const Color(0xFF0C0D10));
        _glint(canvas, _rr(44, 22.6, 49, 24.4, 1));
        _glint(canvas, _rr(51, 22.6, 56, 24.4, 1));
      }
      if (look.headset) {
        fill(_rr(39.5, 20, 43.5, 29, 2), _tone(0.3));
        fill(_rr(56.5, 20, 60.5, 29, 2), _tone(0.3));
        canvas.drawArc(
          const Rect.fromLTWH(41.5, 12, 17, 16),
          pi,
          pi,
          false,
          Paint()
            ..color = _tone(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
    }
    // 위에서 오는 빛(위쪽이 살짝 밝다)
    canvas
      ..drawRect(
        const Rect.fromLTWH(0, 0, 100, 160),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x1FFFFFFF), Color(0x00FFFFFF), Color(0x26000000)],
          ).createShader(const Rect.fromLTWH(0, 0, 100, 160)),
      )
      ..restore();

    // ---------------------------------------------------------------- 무기(어둡게 눌러 실루엣에 맞춤)
    if (weapon != null) {
      final box = Rect.fromCenter(
        center: Offset.zero,
        width: gunLen,
        height: gunLen * 0.4,
      );
      canvas
        ..save()
        ..translate(gunCenter.dx, gunCenter.dy)
        ..rotate(pistol ? 1.25 : gunAngle)
        ..saveLayer(null, Paint()..colorFilter = _darken);
      paintWeapon(canvas, box, weapon);
      canvas
        ..restore()
        ..restore();
    }
    // 장갑(무기 위)
    for (final h in [left, right]) {
      final glove = Path()..addOval(Rect.fromCircle(center: h, radius: 3.4));
      canvas
        ..drawPath(
          glove.shift(const Offset(-0.6, -0.6)),
          Paint()..color = _keyRim,
        )
        ..drawPath(glove, Paint()..color = _tone(0.12));
    }
    canvas.restore();
  }

  /// 고글·선글라스 렌즈가 캐릭터 색으로 살짝 빛난다.
  void _glint(Canvas canvas, Path lens) => canvas
    ..drawPath(
      lens,
      Paint()
        ..color = _keyRim.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
    );

  /// 무기를 실루엣 톤으로(밝기 38%, 모양 구분은 남긴다).
  static const _darken = ColorFilter.matrix([
    0.38, 0, 0, 0, 10, //
    0, 0.38, 0, 0, 11,
    0, 0, 0.4, 0, 13,
    0, 0, 0, 1, 0,
  ]);

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.look != look || old.weaponId != weaponId;
}
