import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart' show FontWeight, TextStyle;

/// 화면 고정 나침반. 바늘(빨강)은 위쪽 기준이고 [angle]만큼 돌아 북쪽을 가리킨다.
/// 링 바깥 바늘 끝 쪽에 'N'을 두고, 글자는 회전을 되돌려 항상 똑바로 그린다.
class Compass extends PositionComponent {
  Compass({required super.position})
    : super(size: Vector2.all(_r * 2), anchor: Anchor.center);

  static const _r = 24.0;
  static final _ring = Paint()
    ..color = const Color(0xAAFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _north = Paint()..color = const Color(0xFFE04848);
  static final _south = Paint()..color = const Color(0xFFDDDDDD);
  static final _label = TextPaint(
    style: const TextStyle(
      color: Color(0xFFE04848),
      fontSize: 12,
      fontWeight: FontWeight.bold,
    ),
  );

  @override
  void render(Canvas canvas) {
    const c = Offset(_r, _r);
    canvas
      ..drawCircle(c, _r, _ring)
      ..drawPath(
        Path()
          ..moveTo(_r, 4)
          ..lineTo(_r - 6, _r)
          ..lineTo(_r + 6, _r)
          ..close(),
        _north,
      )
      ..drawPath(
        Path()
          ..moveTo(_r, _r * 2 - 4)
          ..lineTo(_r - 6, _r)
          ..lineTo(_r + 6, _r)
          ..close(),
        _south,
      );
    canvas
      ..save()
      ..translate(_r, -10)
      ..rotate(-angle);
    _label.render(canvas, 'N', Vector2.zero(), anchor: Anchor.center);
    canvas.restore();
  }
}
