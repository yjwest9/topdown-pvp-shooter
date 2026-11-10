import 'dart:ui';

import 'package:flame/components.dart';

import '../../rules/balance.dart';

/// 칼을 휘두른 자리에 잠깐 보이는 부채꼴 호(decisions 6장). 휘두른 순간의 위치·방향에 고정.
class SwingArc extends PositionComponent {
  SwingArc({
    required Vector2 position,
    required double angle,
    required this.weapon,
    this.mine = true,
  }) : super(position: position, angle: angle);

  final WeaponStats weapon;

  /// 내 휘두름은 흰색, 상대는 빨강(총알 예광탄과 같은 구분).
  final bool mine;

  static const life = 0.15;
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final fade = (1 - _t / life).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: weapon.range),
      -weapon.spread / 2,
      weapon.spread,
      false,
      Paint()
        ..color = (mine ? const Color(0xFFFFFFFF) : const Color(0xFFE53935))
            .withValues(alpha: 0.85 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
  }
}
