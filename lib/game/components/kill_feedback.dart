import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show FontWeight, TextStyle;

/// 내 총알이 맞은 자리에 잠깐 뜨는 흰 X(히트마커).
class HitMarker extends PositionComponent {
  HitMarker({required super.position}) : super(anchor: Anchor.center);

  static const duration = 0.25;
  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, 1 - _age / duration)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    const a = 4.0, b = 10.0;
    for (final (x, y) in [(1, 1), (1, -1), (-1, 1), (-1, -1)]) {
      canvas.drawLine(Offset(a * x, a * y), Offset(b * x, b * y), paint);
    }
  }
}

/// 처치 확인: 화면 위쪽 가운데 빨간 X + "처치" + 상대 이름. 잠깐 커졌다가 사라진다.
class KillBanner extends PositionComponent with HasGameReference {
  static const duration = 1.4;

  /// 마지막으로 처치한 상대. 보이는 동안만 의미가 있다.
  String victim = '';
  double left = 0;

  bool get showing => left > 0;

  void show(String name) {
    victim = name;
    left = duration;
  }

  static const _red = Color(0xFFE0563F);

  @override
  void update(double dt) {
    if (left > 0) left = max(0, left - dt);
    position.setValues(game.size.x / 2, game.size.y * 0.18);
  }

  @override
  void render(Canvas canvas) {
    if (left <= 0) return;
    final t = duration - left;
    final alpha = min(1.0, left / 0.4);
    final pop = 1 + 0.5 * max(0.0, 1 - t / 0.15);
    canvas
      ..save()
      ..scale(pop);
    final x = Paint()
      ..color = _red.withValues(alpha: alpha)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(const Offset(-16, -16), const Offset(16, 16), x)
      ..drawLine(const Offset(16, -16), const Offset(-16, 16), x);
    TextPaint(
      style: TextStyle(
        color: _red.withValues(alpha: alpha),
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
    ).render(canvas, '처치', Vector2(0, 26), anchor: Anchor.topCenter);
    TextPaint(
      style: TextStyle(
        color: Color.fromRGBO(227, 230, 216, alpha),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ).render(canvas, victim, Vector2(0, 54), anchor: Anchor.topCenter);
    canvas.restore();
  }
}
