import 'package:flutter/material.dart';

import '../game/weapon_art.dart';
import '../rules/appearance.dart';

/// 무기 옆모습 그림(decisions 17장). 칸 크기에 맞춰 그린다.
class WeaponArt extends StatelessWidget {
  const WeaponArt(
    this.weaponId, {
    super.key,
    required this.width,
    required this.height,
    this.dim = false,
  });

  final String weaponId;
  final double width;
  final double height;

  /// 아직 안 산 무기.
  final bool dim;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: dim ? 0.4 : 1,
    child: CustomPaint(
      size: Size(width, height),
      painter: _WeaponArtPainter(weaponLook(weaponId)),
    ),
  );
}

class _WeaponArtPainter extends CustomPainter {
  _WeaponArtPainter(this.look);

  final WeaponLook look;

  @override
  void paint(Canvas canvas, Size size) =>
      paintWeapon(canvas, Offset.zero & size, look);

  @override
  bool shouldRepaint(_WeaponArtPainter old) => old.look != look;
}
