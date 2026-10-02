import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../../rules/balance.dart';

/// 화면 전체를 덮는 터치 입력층.
/// 왼쪽 절반: 떠다니는 조이스틱(누른 곳이 중심). 오른쪽 절반: 가로 드래그로 회전.
class TouchControls extends PositionComponent with DragCallbacks {
  TouchControls({required this.onMove, required this.onTurn});

  /// (forward, strafe). 위로 밀면 forward +.
  final void Function(double forward, double strafe) onMove;
  final void Function(double dragDx) onTurn;

  int? _stickPointer;
  final _stickOrigin = Vector2.zero();
  final _stickDrag = Vector2.zero();

  static final _base = Paint()
    ..color = const Color(0x55FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _knob = Paint()..color = const Color(0x88FFFFFF);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  Vector2 get _knobOffset => _stickDrag.clone()..clampLength(0, joystickRadius);

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (_stickPointer == null && event.localPosition.x < size.x / 2) {
      _stickPointer = event.pointerId;
      _stickOrigin.setFrom(event.localPosition);
      _stickDrag.setZero();
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (event.pointerId == _stickPointer) {
      _stickDrag.add(event.localDelta);
      final k = _knobOffset / joystickRadius;
      onMove(-k.y, k.x);
    } else {
      onTurn(event.localDelta.x);
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _release(event.pointerId);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _release(event.pointerId);
  }

  void _release(int pointerId) {
    if (pointerId != _stickPointer) return;
    _stickPointer = null;
    onMove(0, 0);
  }

  @override
  void render(Canvas canvas) {
    if (_stickPointer == null) return;
    final o = _stickOrigin.toOffset();
    canvas
      ..drawCircle(o, joystickRadius, _base)
      ..drawCircle(o + _knobOffset.toOffset(), 20, _knob);
  }
}
