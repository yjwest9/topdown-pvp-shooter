import 'package:flutter/material.dart';

import '../rules/map_select.dart';

/// 봇전·친선전 맵 고르기(decisions 11장). 이름 옆에 크기만 보인다.
class MapChips extends StatelessWidget {
  const MapChips({super.key, required this.selected, required this.onSelected});

  /// 고른 맵 id.
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    // 가로 한 줄. 창이 좁으면 칩 안 글자만 줄어든다(칩 크기·글자는 그대로).
    return Row(
      spacing: 8,
      children: [
        for (final m in selectableMaps)
          Flexible(
            child: ChoiceChip(
              label: FittedBox(fit: BoxFit.scaleDown, child: Text(m.label)),
              selected: selected == m.id,
              onSelected: (_) => onSelected(m.id),
            ),
          ),
      ],
    );
  }
}
