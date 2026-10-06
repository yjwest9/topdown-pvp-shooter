import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart' show FontWeight, TextStyle;

/// 수동 무기 사격 버튼. 누르는 순간부터 사격(탭 다운).
/// 누른 채 끌면 탭이 취소되고 [TouchControls]가 드래그로 이어받아 사격 + 회전.
class FireButton extends PositionComponent with TapCallbacks {
  FireButton({required this.visible, required this.onFire})
    : super(size: Vector2.all(radius * 2), anchor: Anchor.center);

  /// 중심 위치: 오른쪽 70, 아래 82.
  static const right = 70.0, bottom = 82.0, radius = 40.0;

  final bool Function() visible;
  final void Function(bool held) onFire;

  bool held = false;

  static final _idle = Paint()..color = const Color(0x59E0563F);
  static final _on = Paint()..color = const Color(0xBFE0563F);
  static final _text = TextPaint(
    style: const TextStyle(
      color: Color(0xFFE3E6D8),
      fontSize: 13,
      fontWeight: FontWeight.bold,
    ),
  );

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    position = Vector2(size.x - right, size.y - bottom);
  }

  @override
  bool containsLocalPoint(Vector2 point) =>
      visible() && (point - size / 2).length <= radius;

  /// 탭(여기)과 드래그(TouchControls) 둘 다 이걸로 누름/뗌을 알린다.
  void setHeld(bool v) {
    held = v;
    onFire(v);
  }

  @override
  void onTapDown(TapDownEvent event) => setHeld(true);

  @override
  void onTapUp(TapUpEvent event) => setHeld(false);

  @override
  void onTapCancel(TapCancelEvent event) => setHeld(false);

  @override
  void render(Canvas canvas) {
    if (!visible()) return;
    canvas.drawCircle((size / 2).toOffset(), radius, held ? _on : _idle);
    _text.render(canvas, 'FIRE', size / 2, anchor: Anchor.center);
  }
}
