import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart' show FontWeight, TextStyle;

/// 데미지 숫자, MISS. 화면 위쪽으로 떠오르며 사라진다. 회전 시점에서도 똑바로 그린다.
class FloatingText extends PositionComponent {
  FloatingText(
    this.text, {
    required super.position,
    required this.color,
    this.fontSize = 13,
  }) : super(anchor: Anchor.center);

  FloatingText.damage(double damage, {required Vector2 at, bool crit = false})
    : this(
        damage.round().toString(),
        position: at,
        color: crit ? const Color(0xFFFFD84A) : const Color(0xFFFFFFFF),
        fontSize: crit ? 20 : 13,
      );

  FloatingText.miss({required Vector2 at})
    : this('MISS', position: at, color: const Color(0xFFA0A0A0));

  static const duration = 0.8;
  static const rise = 36.0;

  final String text;
  final Color color;
  final double fontSize;
  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= duration) {
      removeFromParent();
      return;
    }
    // 카메라 각도를 따라가면 화면에서 똑바로 보인다. 화면 위 = 월드 (sin θ, −cos θ).
    final cam = findGame()!.camera.viewfinder.angle;
    angle = cam;
    position += Vector2(sin(cam), -cos(cam)) * (rise / duration * dt);
  }

  @override
  void render(Canvas canvas) {
    final alpha = 1 - _age / duration;
    TextPaint(
      style: TextStyle(
        color: color.withValues(alpha: alpha),
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    ).render(canvas, text, Vector2.zero(), anchor: Anchor.center);
  }
}
