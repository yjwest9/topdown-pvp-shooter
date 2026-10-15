import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../rules/balance.dart';
import '../../rules/combat.dart';
import '../../rules/loadout.dart';
import '../../rules/upgrade.dart';
import '../format.dart';
import '../style.dart';
import '../upgrade_widgets.dart';
import '../weapon_art_view.dart';
import 'loadout_view_model.dart';

/// 무기 화면(홈 아래 메뉴 "무기"): 계열 탭, 목록, 상세·구매·장착.
class LoadoutView extends ConsumerWidget {
  const LoadoutView({super.key});

  static const _tabs = [
    (WeaponFamily.rifle, '라이플'),
    (WeaponFamily.sniper, '저격'),
    (WeaponFamily.shotgun, '샷건'),
    (WeaponFamily.pistol, '보조'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(loadoutProvider);
    final vm = ref.read(loadoutProvider.notifier);
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: panelColor,
        toolbarHeight: 44,
        title: Row(
          children: [
            const Text('무기'),
            const SizedBox(width: 24),
            for (final (f, label) in _tabs)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(label),
                  selected: s.family == f,
                  onSelected: (_) => vm.showFamily(f),
                ),
              ),
          ],
        ),
        actions: [
          const Icon(Icons.monetization_on, size: 18, color: amberColor),
          const SizedBox(width: 4),
          Text(commas(s.profile.gold)),
          const SizedBox(width: 16),
        ],
      ),
      // 아래 안전 영역 없음: immersiveSticky에서 키보드·시스템 바가 한 번 뜨면 아래가 떠 보인다(홈과 같음).
      body: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              // 총 그림이 들어가서 조금 넓게(이름이 한 줄에 들어가게).
              width: 240,
              child: ListView(
                children: [
                  for (final w in s.list) _WeaponTile(w, s, () => vm.select(w)),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _Detail(s, vm)),
          ],
        ),
      ),
    );
  }
}

class _WeaponTile extends StatelessWidget {
  const _WeaponTile(this.w, this.s, this.onTap);

  final WeaponStats w;
  final LoadoutState s;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final owned = s.owns(w);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      horizontalTitleGap: 8,
      selected: s.selected == w,
      selectedTileColor: panelColor,
      onTap: onTap,
      // 총 그림. 안 산 무기는 흐리게 + 자물쇠.
      leading: SizedBox(
        width: 56,
        height: 28,
        child: Stack(
          alignment: Alignment.center,
          children: [
            WeaponArt(w.id, width: 56, height: 28, dim: !owned),
            if (!owned)
              Icon(
                Icons.lock,
                size: 16,
                color: lightColor.withValues(alpha: 0.8),
              ),
          ],
        ),
      ),
      title: Text(
        withLevel(w.name, s.levelOf(w)),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: owned ? lightColor : lightColor.withValues(alpha: 0.4),
        ),
      ),
      trailing: s.isEquipped(w)
          ? const Text(
              '장착',
              style: TextStyle(color: amberColor, fontWeight: FontWeight.w900),
            )
          : owned
          ? null
          : Text(
              '${commas(weaponPrice)} G',
              style: TextStyle(color: lightColor.withValues(alpha: 0.5)),
            ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.s, this.vm);

  final LoadoutState s;
  final LoadoutViewModel vm;

  Future<void> _buy(BuildContext context) async {
    final ok = await vm.buy();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '${s.selected.name}을(를) 샀습니다' : '구매하지 못했습니다'),
      ),
    );
  }

  Future<void> _upgrade(BuildContext context) async {
    final r = await vm.upgrade();
    if (r == null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('강화하지 못했습니다. 다시 시도해 주세요')));
    }
  }

  /// 등급·강화 배율을 넣은 한 발 데미지(소수 한 자리).
  static String damageText(WeaponStats w, int level) =>
      (w.damage * gradeMultiplier(Grade.e, level)).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final w = s.selected;
    final level = s.levelOf(w);
    final b = statBars(w, weapons);
    final shotgun = w.family == WeaponFamily.shotgun;
    final rows = [
      ('데미지', b.damage, '${shotgun ? '최대 ' : ''}${damageText(w, level)}'),
      ('연사 속도', b.fireRate, '${(1 / w.fireInterval).toStringAsFixed(1)}발/초'),
      ('사거리', b.range, '${w.range.round()}'),
      ('탄창', b.magazine, '${w.magazine}'),
      ('기동성', b.mobility, '×${w.moveSpeed}'),
    ];
    final ttkText = ttk(
      w,
      damageMultiplier: gradeMultiplier(Grade.e, level),
    ).toStringAsFixed(2);
    // 가로 화면 높이에 맞게 두 칸: 왼쪽은 이름·능력치, 오른쪽은 장단점·강화·장착/구매.
    // 장착/구매 버튼은 오른쪽 칸 맨 아래에 붙어서 스크롤 없이 늘 보인다.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UpgradeFlash(
                        seq: s.upgradeSeq,
                        result: s.upgradeResult,
                        child: Text(
                          withLevel(w.name, level),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const GradeBadge('E'),
                    ],
                  ),
                  WeaponArt(w.id, width: 220, height: 64, dim: !s.owns(w)),
                  Text(
                    'TTK $ttkText초 (체력 100, 전부 명중)',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  for (final (label, ratio, value) in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(width: 64, child: Text(label)),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 8,
                              color: amberColor,
                              backgroundColor: panelColor,
                            ),
                          ),
                          SizedBox(
                            width: 76,
                            child: Text(value, textAlign: TextAlign.right),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('장점  ${w.pros}'),
                Text('단점  ${w.cons}'),
                if (s.owns(w)) ...[
                  const SizedBox(height: 10),
                  UpgradePanel(
                    level: level,
                    gold: s.profile.gold,
                    busy: s.busy,
                    change: level >= maxUpgradeLevel
                        ? ''
                        : '데미지 ${damageText(w, level)} → '
                              '${damageText(w, level + 1)}',
                    onUpgrade: () => unawaited(_upgrade(context)),
                  ),
                ],
                const Spacer(),
                s.owns(w)
                    ? FilledButton(
                        onPressed: s.isEquipped(w)
                            ? null
                            : () => unawaited(vm.equip()),
                        child: Text(s.isEquipped(w) ? '장착 중' : '장착'),
                      )
                    : FilledButton(
                        onPressed: s.canAfford && !s.busy
                            ? () => unawaited(_buy(context))
                            : null,
                        child: Text(
                          s.canAfford
                              ? '구매 ${commas(weaponPrice)} G'
                              : '골드 부족 (${commas(weaponPrice)} G)',
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
