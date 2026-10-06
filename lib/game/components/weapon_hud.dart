import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart' show FontWeight, TextStyle;

import '../../rules/balance.dart';
import '../../rules/weapon_state.dart';

/// 오른쪽 위 무기 슬롯 버튼(주무기 / 보조무기). 누르면 그 무기를 든다.
/// 무기 이름, 탄약 "28 / 30", 발사 방식, 재장전 중엔 진행 바.
class WeaponSlot extends PositionComponent with TapCallbacks {
  WeaponSlot({
    required this.label,
    required this.index,
    required this.weapon,
    required this.active,
    required this.fireMode,
    required this.onTap,
  }) : super(size: Vector2(slotW, slotH));

  static const slotW = 130.0, slotH = 56.0, gap = 8.0, margin = 16.0;

  final String label;

  /// 오른쪽에서 몇 번째(0 = 맨 오른쪽).
  final int index;
  final WeaponState Function() weapon;
  final bool Function() active;
  final FireMode Function() fireMode;
  final void Function() onTap;

  static final _idle = Paint()..color = const Color(0x24E3E6D8);
  static final _on = Paint()..color = const Color(0x59E8B33A);
  static final _edge = Paint()
    ..color = const Color(0x4DE3E6D8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  static final _edgeOn = Paint()
    ..color = const Color(0xFFE8B33A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _small = TextPaint(
    style: const TextStyle(color: Color(0xFF98A089), fontSize: 9),
  );
  static final _name = TextPaint(
    style: const TextStyle(
      color: Color(0xFFE3E6D8),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    ),
  );
  static final _ammo = TextPaint(
    style: const TextStyle(
      color: Color(0xFFE8B33A),
      fontSize: 15,
      fontWeight: FontWeight.bold,
    ),
  );
  static final _barBack = Paint()..color = const Color(0x40E3E6D8);
  static final _bar = Paint()..color = const Color(0xFFE8B33A);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    position = Vector2(size.x - margin - slotW - index * (slotW + gap), margin);
  }

  @override
  void onTapDown(TapDownEvent event) => onTap();

  @override
  void render(Canvas canvas) {
    final w = weapon();
    final on = active();
    final rect = RRect.fromRectAndRadius(
      size.toRect(),
      const Radius.circular(6),
    );
    canvas
      ..drawRRect(rect, on ? _on : _idle)
      ..drawRRect(rect, on ? _edgeOn : _edge);
    final mode = fireMode() == FireMode.auto ? 'AUTO' : 'MANUAL';
    _small.render(canvas, '$label · $mode', Vector2(8, 4));
    _name.render(canvas, w.weapon.id, Vector2(8, 16));
    _ammo.render(canvas, '${w.ammo} / ${w.weapon.magazine}', Vector2(8, 31));
    if (w.reloading) {
      const barW = slotW - 16;
      canvas
        ..drawRect(const Rect.fromLTWH(8, slotH - 6, barW, 3), _barBack)
        ..drawRect(
          Rect.fromLTWH(8, slotH - 6, barW * w.reloadProgress, 3),
          _bar,
        );
    }
  }
}
