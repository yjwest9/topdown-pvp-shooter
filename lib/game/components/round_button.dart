import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart' show FontWeight, TextStyle;

/// HudButtonComponent의 모양. [active]면 강조색.
class RoundButton extends PositionComponent {
  RoundButton({required this.label, required this.active, double radius = 30})
    : super(size: Vector2.all(radius * 2));

  final String label;
  final bool Function() active;

  static final _idle = Paint()..color = const Color(0x24E3E6D8);
  static final _on = Paint()..color = const Color(0xB3E8B33A);
  static final _edge = Paint()
    ..color = const Color(0x4DE3E6D8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  static final _text = TextPaint(
    style: const TextStyle(
      color: Color(0xFFE3E6D8),
      fontSize: 11,
      fontWeight: FontWeight.bold,
    ),
  );

  @override
  void render(Canvas canvas) {
    final c = (size / 2).toOffset();
    final r = size.x / 2;
    canvas
      ..drawCircle(c, r, active() ? _on : _idle)
      ..drawCircle(c, r, _edge);
    _text.render(canvas, label, size / 2, anchor: Anchor.center);
  }
}
