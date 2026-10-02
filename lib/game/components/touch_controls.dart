import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../../rules/balance.dart';

/// 화면 전체를 덮는 터치 입력층.
/// 왼쪽 절반: 떠다니는 조이스틱(누른 곳이 중심). 오른쪽 절반: 가로 드래그로 회전.
/// [buttons] 위에서 시작한 손가락은 무시한다(버튼 누르다 회전되지 않게).
class TouchControls extends PositionComponent with DragCallbacks {
  TouchControls({
    required this.onMove,
    required this.onTurn,
    required this.buttons,
    required this.isRunning,
  });

  /// (forward, strafe, run). 위로 밀면 forward +. 바깥 원까지 끌면 run.
  final void Function(double forward, double strafe, bool run) onMove;
  final void Function(double dragDx) onTurn;
  final List<PositionComponent> buttons;

  /// 바깥 원 강조색 표시용.
  final bool Function() isRunning;

  int? _stickPointer;
  final _ignored = <int>{};
  final _stickOrigin = Vector2.zero();
  final _stickDrag = Vector2.zero();

  static final _base = Paint()
    ..color = const Color(0x55FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _runRing = Paint()
    ..color = const Color(0x40E3E6D8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _runRingActive = Paint()
    ..color = const Color(0xCCE8B33A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _knob = Paint()..color = const Color(0x88FFFFFF);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  /// 손잡이 표시 위치. 달리기 원을 넘으면 그 원까지, 아니면 기본 원까지.
  Vector2 get _knobOffset {
    final limit = _stickDrag.length > runRingRadius
        ? runRingRadius
        : joystickRadius;
    return _stickDrag.clone()..clampLength(0, limit);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    final p = event.localPosition.toOffset();
    if (buttons.any((b) => b.toRect().contains(p))) {
      _ignored.add(event.pointerId);
    } else if (_stickPointer == null && p.dx < size.x / 2) {
      _stickPointer = event.pointerId;
      _stickOrigin.setFrom(event.localPosition);
      _stickDrag.setZero();
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_ignored.contains(event.pointerId)) return;
    if (event.pointerId == _stickPointer) {
      _stickDrag.add(event.localDelta);
      final k = _stickDrag.clone()..clampLength(0, joystickRadius);
      onMove(
        -k.y / joystickRadius,
        k.x / joystickRadius,
        _stickDrag.length > runRingRadius,
      );
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
    _ignored.remove(pointerId);
    if (pointerId != _stickPointer) return;
    _stickPointer = null;
    onMove(0, 0, false);
  }

  @override
  void render(Canvas canvas) {
    if (_stickPointer == null) return;
    final o = _stickOrigin.toOffset();
    canvas
      ..drawCircle(o, joystickRadius, _base)
      ..drawCircle(o + _knobOffset.toOffset(), 20, _knob);
    _dashedCircle(
      canvas,
      o,
      runRingRadius,
      isRunning() ? _runRingActive : _runRing,
    );
  }

  static void _dashedCircle(Canvas canvas, Offset c, double r, Paint paint) {
    const dashes = 24;
    const sweep = 2 * pi / dashes;
    final rect = Rect.fromCircle(center: c, radius: r);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.5, false, paint);
    }
  }
}
