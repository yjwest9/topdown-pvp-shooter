import 'dart:math';

import 'package:flutter/material.dart';

import '../game/weapon_art.dart';
import '../rules/appearance.dart';

/// 정면에서 본 서 있는 캐릭터(홈·캐릭터 화면, decisions 8장). 손에는 [weaponId] 무기.
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

  static final _line = Paint()
    ..color = const Color(0x59000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeJoin = StrokeJoin.round;

  void _shape(Canvas c, Path p, int color) => c
    ..drawPath(p, Paint()..color = Color(color))
    ..drawPath(p, _line);

  Path _rr(double l, double t, double r, double b, double radius) =>
      Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)));

  /// [color]를 [f](0~1)만큼 어둡게.
  int _darker(int color, double f) {
    final c = Color(color);
    return Color.from(
      alpha: c.a,
      red: c.r * (1 - f),
      green: c.g * (1 - f),
      blue: c.b * (1 - f),
    ).toARGB32();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height / 160;
    canvas
      ..save()
      ..scale(s);
    final accent = look.accent ?? _darker(look.top, 0.3);

    // 그림자
    canvas.drawOval(
      const Rect.fromLTWH(22, 144, 56, 12),
      Paint()..color = const Color(0x40000000),
    );
    // 배낭(몸 뒤)
    if (look.backpack) _shape(canvas, _rr(22, 70, 78, 116, 9), accent);
    // 다리·신발
    _shape(canvas, _rr(35, 110, 49, 146, 5), look.pants);
    _shape(canvas, _rr(51, 110, 65, 146, 5), look.pants);
    _shape(canvas, _rr(31, 139, 49, 150, 5), look.shoes);
    _shape(canvas, _rr(51, 139, 69, 150, 5), look.shoes);
    // 몸통
    _shape(canvas, _rr(28, 64, 72, 118, 11), look.top);
    if (look.tie) {
      _shape(
        canvas,
        Path()..addPolygon(const [
          Offset(42, 64),
          Offset(58, 64),
          Offset(50, 86),
        ], true),
        0xFFF2F2F2,
      );
      _shape(
        canvas,
        Path()..addPolygon(const [
          Offset(48, 66),
          Offset(52, 66),
          Offset(54, 88),
          Offset(50, 94),
          Offset(46, 88),
        ], true),
        accent,
      );
    }
    if (look.backpack) {
      _shape(canvas, _rr(33, 64, 39, 112, 2), _darker(accent, 0.15));
      _shape(canvas, _rr(61, 64, 67, 112, 2), _darker(accent, 0.15));
    }
    // 팔(어깨에서 총을 잡는 손까지)
    final weapon = weaponId == null ? null : weaponLook(weaponId!);
    final pistol = weapon?.pistol ?? false;
    final arm = Paint()
      ..color = Color(look.top)
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    final armEdge = Paint()
      ..color = const Color(0x59000000)
      ..strokeWidth = 13.5
      ..strokeCap = StrokeCap.round;
    final (leftHand, rightHand) = weapon == null
        ? (const Offset(24, 108), const Offset(76, 108))
        : pistol
        ? (const Offset(26, 106), const Offset(68, 98))
        : (const Offset(64, 92), const Offset(42, 104));
    for (final (from, to) in [
      (const Offset(31, 72), leftHand),
      (const Offset(69, 72), rightHand),
    ]) {
      canvas
        ..drawLine(from, to, armEdge)
        ..drawLine(from, to, arm);
    }
    // 무기(몸 앞을 가로질러 비스듬히, 권총은 오른손에)
    if (weapon != null) {
      canvas
        ..save()
        ..translate(pistol ? 78 : 50, pistol ? 92 : 96)
        ..rotate(pistol ? -0.15 : -0.38);
      final w = pistol ? 46.0 : 104 * weapon.length / 124 + 10;
      paintWeapon(
        canvas,
        Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.4),
        weapon,
      );
      canvas.restore();
    }
    // 손
    for (final h in [leftHand, rightHand]) {
      _shape(
        canvas,
        Path()..addOval(Rect.fromCircle(center: h, radius: 6)),
        look.skin,
      );
    }
    // 목·머리·귀
    _shape(canvas, _rr(44, 56, 56, 68, 3), look.skin);
    _shape(
      canvas,
      Path()..addOval(const Rect.fromLTWH(22, 38, 11, 13)),
      look.skin,
    );
    _shape(
      canvas,
      Path()..addOval(const Rect.fromLTWH(67, 38, 11, 13)),
      look.skin,
    );
    _shape(
      canvas,
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(50, 40), radius: 23)),
      look.skin,
    );
    _hair(canvas, accent);
    _face(canvas);
    canvas.restore();
  }

  void _hair(Canvas canvas, int accent) {
    if (look.helmet) {
      final helmet = _darker(look.top, 0.1);
      _shape(
        canvas,
        Path()
          ..moveTo(23, 32)
          ..arcTo(const Rect.fromLTWH(23, 9, 54, 46), pi, pi, false)
          ..close(),
        helmet,
      );
      _shape(canvas, _rr(20, 29, 80, 34, 3), _darker(helmet, 0.2));
      return;
    }
    final hair = Path()
      ..moveTo(27, 40)
      ..arcTo(const Rect.fromLTWH(27, 16, 46, 44), pi, pi, false)
      ..lineTo(73, 32)
      ..quadraticBezierTo(60, 26, 44, 30)
      ..quadraticBezierTo(32, 32, 27, 40)
      ..close();
    if (look.messyHair) {
      // 덥수룩한 머리: 위쪽에 둥근 덩어리를 겹친다.
      for (final (x, y, r) in [
        (34.0, 24.0, 8.0),
        (44.0, 18.0, 9.0),
        (56.0, 18.0, 9.0),
        (66.0, 25.0, 8.0),
      ]) {
        hair.addOval(Rect.fromCircle(center: Offset(x, y), radius: r));
      }
    }
    _shape(canvas, hair, look.hair);
  }

  void _face(Canvas canvas) {
    final eye = Paint()..color = const Color(0xFF2A2420);
    if (look.sunglasses) {
      _shape(canvas, _rr(32, 39, 68, 43, 2), 0xFF15161A);
      _shape(canvas, _rr(34, 40, 48, 49, 4), 0xFF15161A);
      _shape(canvas, _rr(52, 40, 66, 49, 4), 0xFF15161A);
    } else {
      canvas
        ..drawOval(const Rect.fromLTWH(39, 40, 5, 7), eye)
        ..drawOval(const Rect.fromLTWH(56, 40, 5, 7), eye);
      // 눈썹
      final brow = Paint()
        ..color = Color(_darker(look.hair, 0.1))
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas
        ..drawLine(const Offset(37, 36), const Offset(45, 35), brow)
        ..drawLine(const Offset(55, 35), const Offset(63, 36), brow);
    }
    canvas.drawArc(
      const Rect.fromLTWH(44, 48, 12, 7),
      0.2,
      pi - 0.4,
      false,
      Paint()
        ..color = const Color(0xFF7A3F2E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.look != look || old.weaponId != weaponId;
}
