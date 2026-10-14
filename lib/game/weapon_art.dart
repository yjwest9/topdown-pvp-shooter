import 'dart:math';
import 'dart:ui';

import '../rules/appearance.dart';

/// 무기 옆모습(오른쪽이 총구)을 [box] 안에 맞춰 그린다(decisions 17장).
/// [refLength]를 주면 그 길이가 [box] 너비가 되게 같은 비율로 그린다(목록에서 권총은 작게).
/// 그림 단위: x 0(개머리판 끝) ~ length(총구), y는 총열 높이 0 기준 위 −14 ~ 아래 +22.
void paintWeapon(
  Canvas canvas,
  Rect box,
  WeaponLook look, {
  double? refLength,
}) {
  const top = -14.0, bottom = 22.0;
  final l = look.length;
  final s = min(box.width / (refLength ?? l), box.height / (bottom - top));
  canvas
    ..save()
    // 가로는 가운데, 세로는 칸 가운데에 그림 범위의 가운데를 맞춘다.
    ..translate(
      box.center.dx - l * s / 2,
      box.center.dy - (top + bottom) / 2 * s,
    )
    ..scale(s);
  _WeaponPainter(canvas, look).paint();
  canvas.restore();
}

class _WeaponPainter {
  _WeaponPainter(this.canvas, this.look);

  final Canvas canvas;
  final WeaponLook look;

  double get l => look.length;

  static const _metal = Color(0xFF4B5157);
  static const _metalLight = Color(0xFF6A7178);
  static const _dark = Color(0xFF2C3034);
  static final _outline = Paint()
    ..color = const Color(0xFF15181B)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..strokeJoin = StrokeJoin.round;

  Color get _furniture => switch (look.finish) {
    Finish.black => const Color(0xFF353A40),
    Finish.wood => const Color(0xFF9A6436),
    Finish.olive => const Color(0xFF66733F),
    Finish.tan => const Color(0xFFB09464),
  };

  /// 채우고 어두운 외곽선(밝은·어두운 바탕 모두에서 모양이 보이게).
  void _fill(Path p, Color color) => canvas
    ..drawPath(p, Paint()..color = color)
    ..drawPath(p, _outline);

  Path _rect(double l, double t, double r, double b, [double radius = 1]) =>
      Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)));

  Path _poly(List<Offset> pts) => Path()..addPolygon(pts, true);

  void _stroke(Path p, Color color, double width) => canvas
    ..drawPath(
      p,
      Paint()
        ..color = const Color(0xFF15181B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    )
    ..drawPath(
      p,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

  void paint() {
    if (look.pistol) return _pistol();
    if (look.barrels == 2) return _doubleBarrel();
    if (look.bipod) _bipod();
    _stock();
    _barrel(look.bullpup ? 0.86 * l : 0.82 * l);
    _magazine();
    _receiver();
    _grip();
    _optic();
  }

  // 몸통(+ 불펍이면 개머리판까지 한 덩어리).
  void _receiver() {
    if (look.bullpup) {
      _fill(_rect(0, -6, 0.70 * l, 6, 2), _metal);
      _fill(_rect(0, -6, 3, 7), _dark); // 개머리 패드
      _fill(_rect(0.70 * l, -4, 0.86 * l, 4), _furniture);
      return;
    }
    _fill(_rect(0.25 * l, -5, 0.58 * l, 5, 1.5), _metal);
    // 총열 덮개(나무·올리브·황갈색이면 그 색).
    if (!look.suppressor) {
      final end = look.pump ? 0.62 * l : 0.82 * l;
      _fill(
        _rect(0.58 * l, -4, end, 4),
        look.finish == Finish.black ? const Color(0xFF3A3F45) : _furniture,
      );
    }
    // 장전 손잡이
    _fill(_rect(0.50 * l, -3, 0.54 * l, 0), _metalLight);
  }

  void _barrel(double from) {
    if (look.suppressor) {
      _fill(_rect(0.56 * l, -4.5, l, 4.5, 2), _dark);
      for (var x = 0.64 * l; x < l - 2; x += 0.06 * l) {
        canvas.drawLine(Offset(x, -4.5), Offset(x, 4.5), _outline);
      }
      return;
    }
    _fill(_rect(from - 2, -1.6, l, 1.6, 0.5), _dark);
    _fill(_rect(l - 6, -5, l - 3.5, -1.6, 0.3), _dark); // 가늠쇠
    if (look.magazine == Magazine.tube) {
      _fill(_rect(0.58 * l, 2, 0.94 * l, 6, 1.5), _metal);
    }
    if (look.pump) {
      _fill(_rect(0.62 * l, 1, 0.78 * l, 9, 2), _furniture);
      for (var x = 0.65 * l; x < 0.76 * l; x += 0.03 * l) {
        canvas.drawLine(Offset(x, 2.5), Offset(x, 7.5), _outline);
      }
    }
  }

  void _stock() {
    final end = 0.27 * l;
    switch (look.stock) {
      case Stock.none:
        return;
      case Stock.solid:
        _fill(
          _poly([
            const Offset(0, -3),
            Offset(end, -4),
            Offset(end, 5),
            const Offset(0, 9),
          ]),
          _furniture,
        );
      case Stock.thumbhole:
        final p =
            _poly([
                const Offset(0, -3),
                Offset(end, -4),
                Offset(end, 5),
                const Offset(0, 9),
              ])
              ..addRRect(
                RRect.fromLTRBR(
                  0.10 * l,
                  0,
                  0.21 * l,
                  4,
                  const Radius.circular(2),
                ),
              )
              ..fillType = PathFillType.evenOdd;
        _fill(p, _furniture);
      case Stock.skeleton:
        _stroke(
          _poly([
            const Offset(1.5, -2),
            Offset(end, -3),
            Offset(end, 4),
            const Offset(1.5, 7.5),
          ]),
          _furniture,
          2.4,
        );
      case Stock.folding:
        _stroke(
          Path()
            ..moveTo(end, -2)
            ..lineTo(2, -2)
            ..moveTo(end, 3)
            ..lineTo(2, 6),
          _metal,
          1.8,
        );
    }
    _fill(_rect(0, -3.5, 2.5, 9), _dark); // 개머리 패드
  }

  void _grip() {
    final x = look.bullpup ? 0.58 * l : 0.38 * l;
    final grip = look.finish == Finish.black ? _dark : _furniture;
    _fill(
      _poly([
        Offset(x - 2, 5),
        Offset(x + 4, 5),
        Offset(x + 1, 16),
        Offset(x - 5, 16),
      ]),
      grip,
    );
    // 방아쇠울
    _stroke(
      Path()..addArc(Rect.fromLTRB(x + 4, 3, x + 10, 9), 0, pi),
      _dark,
      0.8,
    );
  }

  void _magazine() {
    final x = look.bullpup ? 0.36 * l : 0.46 * l;
    switch (look.magazine) {
      case Magazine.none || Magazine.tube:
        return;
      case Magazine.box:
        _fill(_rect(x, 4, x + 0.06 * l, 17, 1), _dark);
      case Magazine.curved:
        _fill(
          Path()
            ..moveTo(x, 4)
            ..lineTo(x + 0.065 * l, 4)
            ..quadraticBezierTo(x + 0.08 * l, 12, x + 0.11 * l, 19)
            ..lineTo(x + 0.05 * l, 20)
            ..quadraticBezierTo(x + 0.02 * l, 12, x, 4)
            ..close(),
          _dark,
        );
      case Magazine.ammoBox:
        _fill(_rect(x - 0.04 * l, 4, x + 0.10 * l, 18, 1.5), _metalLight);
        canvas.drawLine(
          Offset(x - 0.04 * l, 11),
          Offset(x + 0.10 * l, 11),
          _outline,
        );
    }
  }

  void _optic() {
    switch (look.optic) {
      case Optic.none:
        return;
      case Optic.redDot:
        _fill(_rect(0.40 * l, -10, 0.47 * l, -5, 1), _dark);
        canvas.drawCircle(
          Offset(0.435 * l, -7.5),
          1,
          Paint()..color = const Color(0xFFE0563F),
        );
      case Optic.scope || Optic.longScope:
        final (a, b) = look.optic == Optic.scope ? (0.30, 0.58) : (0.24, 0.64);
        _fill(_rect(a * l + 3, -7, a * l + 6, -4.5), _dark); // 받침
        _fill(_rect(b * l - 6, -7, b * l - 3, -4.5), _dark);
        _fill(_rect(a * l, -12.5, a * l + 5, -6.5, 1), _dark); // 대물·접안
        _fill(_rect(b * l - 5, -13, b * l, -6, 1), _dark);
        _fill(_rect(a * l + 4, -11.5, b * l - 4, -7.5, 1), _metal);
        canvas.drawLine(
          Offset(b * l - 0.5, -12),
          Offset(b * l - 0.5, -7),
          Paint()
            ..color = const Color(0xFF7FD4F0)
            ..strokeWidth = 1,
        );
      case Optic.carryHandle:
        final (a, b) = look.bullpup ? (0.22, 0.70) : (0.32, 0.54);
        _stroke(
          Path()
            ..moveTo(a * l, -5)
            ..lineTo(a * l + 2, -11)
            ..lineTo(b * l - 2, -11)
            ..lineTo(b * l, -5),
          _dark,
          2.2,
        );
    }
  }

  void _bipod() {
    _stroke(
      Path()
        ..moveTo(0.78 * l, 3)
        ..lineTo(0.72 * l, 20)
        ..moveTo(0.80 * l, 3)
        ..lineTo(0.88 * l, 20),
      _dark,
      1.6,
    );
  }

  void _doubleBarrel() {
    _fill(
      _poly([
        Offset(0.04 * l, -1),
        Offset(0.30 * l, -4),
        Offset(0.32 * l, 5),
        Offset(0.20 * l, 7),
        Offset(0.12 * l, 17),
        Offset(0.02 * l, 15),
      ]),
      _furniture,
    );
    _fill(_rect(0.30 * l, -5, 0.44 * l, 5, 1.5), _metal);
    _fill(_rect(0.42 * l, -4.5, l, -0.5, 1), _dark);
    _fill(_rect(0.42 * l, -0.5, l, 3.5, 1), _metal);
    _fill(_rect(0.44 * l, 2.5, 0.74 * l, 7, 2), _furniture);
    _stroke(
      Path()..addArc(Rect.fromLTRB(0.30 * l, 2, 0.40 * l, 10), 0, pi),
      _dark,
      1,
    );
  }

  void _pistol() {
    _fill(
      _poly([
        Offset(0.10 * l, 1),
        Offset(0.40 * l, 1),
        Offset(0.34 * l, 16),
        Offset(0.04 * l, 16),
      ]),
      const Color(0xFF3A3530),
    );
    _fill(_rect(0.08 * l, 1, 0.86 * l, 4.5, 1), _dark); // 몸체
    _fill(_rect(0, -5.5, l, 1.5, 1.2), _metal); // 슬라이드
    for (var x = 0.08 * l; x < 0.30 * l; x += 0.05 * l) {
      canvas.drawLine(Offset(x, -4.5), Offset(x, 0.5), _outline);
    }
    _fill(_rect(l - 3, -7, l - 1.5, -5.5, 0.3), _dark); // 가늠쇠
    _stroke(
      Path()..addArc(Rect.fromLTRB(0.38 * l, 1, 0.62 * l, 9), 0, pi),
      _dark,
      1.2,
    );
  }
}
