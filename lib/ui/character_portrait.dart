import 'package:flutter/material.dart';

import '../rules/appearance.dart';

/// 캐릭터 그림(기본 포즈, decisions 8장). 게임 그림은 오른쪽을 보니 위를 보게 돌려서 보여 준다.
/// [size]는 화면에서 차지하는 세로 길이.
class CharacterPortrait extends StatelessWidget {
  const CharacterPortrait(
    this.characterId, {
    super.key,
    required this.size,
    this.dim = false,
  });

  final String characterId;
  final double size;

  /// 아직 안 산 캐릭터.
  final bool dim;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: dim ? 0.4 : 1,
    child: RotatedBox(
      quarterTurns: 3,
      child: Image.asset(
        'assets/images/${characterSprite(characterId, Pose.stand)}',
        width: size,
        // 기본(scaleDown)은 원본보다 크게는 안 그려서, 키우려면 contain이 필요하다.
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    ),
  );
}
